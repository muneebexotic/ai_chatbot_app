import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
// The SDK exports its own `AuthUser`, which is a different thing from ours:
// theirs is the wire shape, ours is the domain model in features/auth/domain.
// Hidden rather than aliased so no call site can pick the wrong one by
// accident.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'package:ai_chatbot_app/core/logging/log.dart';
import 'package:ai_chatbot_app/core/result/app_failure.dart';
import 'package:ai_chatbot_app/core/result/result.dart';
import 'package:ai_chatbot_app/features/auth/domain/auth_user.dart';

/// Supabase-backed authentication (PRD §9.2, Milestone 2).
///
/// Replaces the Firebase half of `providers/auth_provider.dart`. Three rules
/// that class broke and this one does not:
///
/// * **No `BuildContext`.** It takes a client and nothing else, so it can be
///   driven in a test with no widget tree (F3).
/// * **No `null` to signal failure.** Every method returns [Result], and every
///   error is mapped onto the [AppFailure] taxonomy rather than collapsing to
///   a bool (F4).
/// * **It does not know about money.** Entitlements and usage are server-owned
///   and read elsewhere. The old class returned `canSendMessage()` from the
///   same object that held the display name.
///
/// ## On error mapping
///
/// Supabase reports auth errors with a machine-readable `code` on
/// [AuthException]. That is matched first, because it is stable. Message-text
/// matching is a fallback only, for older server builds and for the handful of
/// errors that still arrive without a code — it is deliberately last, since
/// matching on prose breaks silently when the prose changes.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// The current identity, or null when signed out.
  ///
  /// Reads only what the session already holds, so it is synchronous and safe
  /// to call during a build. The display name comes from `profiles` and needs
  /// a round trip — see [loadProfile].
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  bool get isSignedIn => _auth.currentSession != null;

  /// Emits on sign-in, sign-out, token refresh, and user update.
  ///
  /// The app should treat this as the source of truth rather than caching the
  /// result of a sign-in call: a session can also end because the refresh
  /// token was revoked, which no call site would otherwise hear about.
  Stream<AuthUser?> get authStateChanges =>
      _auth.onAuthStateChange.map((event) => _toAuthUser(event.session?.user));

  Future<Result<AuthUser>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _guard(() async {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        // Read by the `handle_new_user` trigger to seed profiles.display_name.
        data: displayName == null || displayName.trim().isEmpty
            ? null
            : {'display_name': displayName.trim()},
      );

      final user = response.user;
      if (user == null) {
        return const Err<AuthUser>(UnknownFailure());
      }

      // With email confirmation on, sign-up succeeds but yields no session.
      // That is not an error — it is the confirm-your-email state, and the UI
      // must say so rather than appearing to hang on a half-signed-in user.
      if (response.session == null) {
        return const Err<AuthUser>(
          AuthFailure(AuthFailureReason.emailNotConfirmed),
        );
      }

      return Ok(_toAuthUser(user)!);
    });
  }

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    return _guard(() async {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return const Err<AuthUser>(
          AuthFailure(AuthFailureReason.invalidCredentials),
        );
      }
      return Ok(_toAuthUser(user)!);
    });
  }

  Future<Result<void>> signOut() async {
    return _guard(() async {
      await _auth.signOut();
      return const Ok<void>(null);
    });
  }

  /// Sends the reset email.
  ///
  /// Succeeds whether or not the address has an account. That is intentional
  /// and matches [AuthFailureReason.invalidCredentials]: a reset endpoint that
  /// reports "no such user" is an account-enumeration oracle. The UI copy must
  /// therefore be "if that address has an account, we've sent a link" rather
  /// than "email sent", which would be a claim we have not verified.
  Future<Result<void>> sendPasswordReset(String email) async {
    return _guard(() async {
      await _auth.resetPasswordForEmail(email.trim());
      return const Ok<void>(null);
    });
  }

  /// Starts Google sign-in (PRD §9.2).
  ///
  /// Opens the system browser, not an in-app webview. Google blocks OAuth in
  /// embedded webviews outright — `disallowed_useragent` — and it is the right
  /// call anyway: a webview asking for a Google password is indistinguishable
  /// from a phishing screen, and the user cannot see the address bar to tell.
  ///
  /// Returns [Ok] once the browser has been handed the request, **not** once
  /// the user is signed in. The rest of the flow arrives out-of-band: Google
  /// redirects to Supabase, Supabase redirects to
  /// `com.muscodes.kalaam://login-callback/`, Android routes that to the
  /// activity, and the session surfaces on [authStateChanges]. Anything that
  /// needs to react to the *result* must watch that stream — a caller awaiting
  /// this future and then reading [currentUser] will usually read null,
  /// because the user has not touched the consent screen yet.
  Future<Result<void>> signInWithGoogle() async {
    return _guard(() async {
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.muscodes.kalaam://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return const Ok<void>(null);
    });
  }

  /// Permanently deletes the account and everything it owns (R9.5.2).
  ///
  /// Calls the `delete-account` Edge Function, which runs under the service
  /// role because a client cannot delete its own `auth.users` row — and should
  /// not be able to, since anything that can do that can bypass RLS.
  ///
  /// The server takes the user id from the caller's JWT, not from anything
  /// sent here. There is deliberately no parameter on this method: an id
  /// argument would be a lie, since the server would ignore it.
  ///
  /// Signs out locally afterwards. Without that the app holds a token for an
  /// account that no longer exists, and every later request fails with a
  /// confusing 401 rather than a clean signed-out state.
  Future<Result<void>> deleteAccount() async {
    if (currentUser == null) {
      return const Err(UnauthorizedFailure());
    }

    return _guard(() async {
      await _client.functions.invoke('delete-account', method: HttpMethod.post);

      // Best-effort: the account is already gone server-side, so a failure to
      // clear the local session must not be reported as a failed deletion.
      // Saying "deletion failed" about data that is definitely deleted is the
      // worse of the two wrong answers.
      try {
        await _auth.signOut();
      } catch (e) {
        Log.w('deleteAccount: local sign-out failed after deletion', error: e);
      }

      return const Ok<void>(null);
    });
  }

  /// Fetches the display name from `profiles`.
  ///
  /// Separate from [currentUser] because it costs a round trip and most call
  /// sites only need the id. Returns the user unchanged when there is no row
  /// yet rather than failing — the trigger creates it, but a caller racing
  /// sign-up should not see an error for a row that is about to exist.
  Future<Result<AuthUser>> loadProfile() async {
    final user = currentUser;
    if (user == null) {
      return const Err(UnauthorizedFailure());
    }

    return _guard(() async {
      final row = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) return Ok(user);
      return Ok(user.copyWith(displayName: row['display_name'] as String?));
    });
  }

  AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  /// Runs [body], turning anything thrown into a typed [AppFailure].
  ///
  /// [body] returns a `Result` rather than a value so a method can report a
  /// domain failure — "no session, confirm your email" — without throwing to
  /// signal it.
  Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } on AuthException catch (e, s) {
      final failure = mapAuthException(e, s);
      Log.w('auth failed: ${failure.code}', error: e);
      return Err<T>(failure);
    } on PostgrestException catch (e, s) {
      Log.w('auth: postgrest error ${e.code}', error: e);
      return Err<T>(UnknownFailure(cause: e, stackTrace: s));
    } on FunctionException catch (e, s) {
      // An Edge Function that rejects the caller reports 401 the same way the
      // auth endpoints do, and it means the same thing to the user.
      Log.w('auth: function error ${e.status}', error: e);
      return Err<T>(
        e.status == 401 || e.status == 403
            ? UnauthorizedFailure(cause: e, stackTrace: s)
            : UnknownFailure(cause: e, stackTrace: s),
      );
    } on SocketException catch (e, s) {
      return Err<T>(OfflineFailure(cause: e, stackTrace: s));
    } on http.ClientException catch (e, s) {
      // The SDK wraps transport failures in this rather than SocketException
      // on some platforms, so both have to be caught or a plane-mode sign-in
      // reports "unknown" instead of "offline".
      return Err<T>(OfflineFailure(cause: e, stackTrace: s));
    } on TimeoutException catch (e, s) {
      return Err<T>(OfflineFailure(cause: e, stackTrace: s));
    } catch (e, s) {
      Log.e('auth: unclassified error', error: e, stackTrace: s);
      return Err<T>(UnknownFailure(cause: e, stackTrace: s));
    }
  }

  /// Maps a Supabase [AuthException] onto the taxonomy.
  ///
  /// Ordering matters: `code` first because it is stable, then HTTP status,
  /// then message text as a last resort.
  ///
  /// Public for testing. This is the one piece of real logic in the class —
  /// everything else delegates to the SDK — and reaching it through a live
  /// client would mean provoking each error against a real project, which is
  /// slow, flaky, and impossible for the codes the server rarely emits.
  @visibleForTesting
  static AppFailure mapAuthException(AuthException e, StackTrace s) {
    switch (e.code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return AuthFailure(
          AuthFailureReason.invalidCredentials,
          cause: e,
          stackTrace: s,
        );
      case 'user_already_exists':
      case 'email_exists':
        return AuthFailure(
          AuthFailureReason.emailAlreadyRegistered,
          cause: e,
          stackTrace: s,
        );
      case 'weak_password':
        return AuthFailure(
          AuthFailureReason.weakPassword,
          cause: e,
          stackTrace: s,
        );
      case 'email_not_confirmed':
        return AuthFailure(
          AuthFailureReason.emailNotConfirmed,
          cause: e,
          stackTrace: s,
        );
      case 'validation_failed':
      case 'email_address_invalid':
        return AuthFailure(
          AuthFailureReason.invalidEmail,
          cause: e,
          stackTrace: s,
        );
      case 'signup_disabled':
        return AuthFailure(
          AuthFailureReason.signUpDisabled,
          cause: e,
          stackTrace: s,
        );
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return RateLimitedFailure(cause: e, stackTrace: s);
    }

    if (e.statusCode == '429') {
      return RateLimitedFailure(cause: e, stackTrace: s);
    }
    if (e.statusCode == '401' || e.statusCode == '403') {
      return UnauthorizedFailure(cause: e, stackTrace: s);
    }

    // Last resort. Matching on prose breaks when the prose changes, which is
    // exactly why it sits below both checks above.
    final message = e.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return AuthFailure(
        AuthFailureReason.emailAlreadyRegistered,
        cause: e,
        stackTrace: s,
      );
    }
    if (message.contains('invalid login credentials')) {
      return AuthFailure(
        AuthFailureReason.invalidCredentials,
        cause: e,
        stackTrace: s,
      );
    }
    if (message.contains('password should be at least')) {
      return AuthFailure(
        AuthFailureReason.weakPassword,
        cause: e,
        stackTrace: s,
      );
    }

    return UnknownFailure(cause: e, stackTrace: s);
  }
}
