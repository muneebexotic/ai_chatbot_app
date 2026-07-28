import 'dart:async';

// `foundation`, not `material`. This class holds state; it does not build
// widgets, and importing Material is how the old one drifted into showing
// dialogs and holding a BuildContext (F3).
import 'package:flutter/foundation.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/features/auth/data/auth_repository.dart';
import 'package:speakwise/features/auth/domain/auth_user.dart';

import '../services/payment_service.dart';

/// Session state for the app, backed by Supabase (PRD §9.2, Milestone 2).
///
/// ## What changed, and what deliberately did not
///
/// Firebase Auth and Firestore are gone from this class. Identity now comes
/// from [AuthRepository]; every method that can fail returns [Result] instead
/// of throwing a string-carrying exception (F4).
///
/// **Usage counters and entitlements did not move to Supabase, and cannot.**
/// The old class stored `dailyUsage` on a Firestore user document the client
/// wrote directly. The equivalent Postgres tables — `usage_daily` and
/// `entitlements` — are service-role write only by design (R9.5.1), because a
/// client that can write its own usage row can reset its own quota and a
/// client that can write its own entitlement can grant itself a subscription.
/// There is no client-writable equivalent to port to, on purpose.
///
/// So those responsibilities stay on [PaymentService], which counts locally,
/// until the gateway takes them over server-side in Milestone 3 (R9.3.4, which
/// requires usage to be recorded atomically with the response it accounts
/// for). Until then the counters are advisory and trivially resettable by
/// reinstalling — which was equally true before, and is exactly what F2 exists
/// to fix.
///
/// This class is still a `ChangeNotifier` (DECISIONS D5) because its consumers
/// — chat, settings, subscription — are rewritten in Milestones 3 and 6, and
/// converting it now would mean rewriting them twice.
class AuthProvider with ChangeNotifier {
  AuthProvider(this._repository) {
    _initialize();
  }

  final AuthRepository _repository;
  final PaymentService _paymentService = PaymentService();

  AuthUser? _user;
  bool _isInitialized = false;
  StreamSubscription<AuthUser?>? _authSubscription;

  // ── Getters ────────────────────────────────────────────────────────────────

  AuthUser? get user => _user;

  /// Retained so the sign-in flows that check `isLoggedIn && currentUser !=
  /// null` keep reading naturally. There is no longer a second user object to
  /// wait for, so this is the same value as [user].
  AuthUser? get currentUser => _user;

  bool get isLoggedIn => _user != null;

  /// False until the first auth event has been seen.
  ///
  /// This is the state the old implementation could not express: it computed
  /// `isLoggedIn` from two nullable fields, so "still restoring the session"
  /// and "signed out" were indistinguishable, and the splash screen had to
  /// guess which one it was looking at.
  bool get isInitialized => _isInitialized;

  /// Always false. Google sign-in is not wired to Supabase yet — see
  /// [signInWithGoogle]. Kept so call sites compile unchanged.
  bool get isGoogleSignIn => false;

  String get displayName => _user?.displayName ?? 'User';

  String get email => _user?.email ?? '';

  /// Supabase has no avatar field in `profiles` (§9.5 does not define one), so
  /// this is always null until a milestone adds one.
  String? get userPhotoUrl => null;

  PaymentService get paymentService => _paymentService;

  /// Local Play Billing state, NOT server truth.
  ///
  /// F2 requires entitlements to be server-decided and verified against the
  /// Play Developer API before anything is written. That lands in Milestone 6
  /// against the `entitlements` table. Reading this to decide what to *display*
  /// is fine; reading it to decide what to *allow* is the bug F2 names.
  bool get isPremium => _paymentService.isPremium;

  String get subscriptionStatus => isPremium ? 'Premium' : 'Free Plan';

  String get usageText {
    if (isPremium) return 'Unlimited';
    final used = _paymentService.dailyMessageCount;
    return '$used / ${PaymentService.freeDailyMessages} messages today';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    try {
      await _paymentService.initialize();

      // Seed from the session the SDK already restored from disk, so a
      // returning user is signed in on the first frame rather than after the
      // first stream event.
      _user = _repository.currentUser;

      _authSubscription = _repository.authStateChanges.listen(
        _handleAuthChange,
        onError: (Object e) => Log.w('auth stream error', error: e),
      );

      if (_user != null) {
        await _onSignedIn(_user!);
      }
    } catch (e, s) {
      Log.e('AuthProvider initialisation failed', error: e, stackTrace: s);
    } finally {
      // Set even on failure. A stuck `false` here leaves the app on the splash
      // screen forever, which is a worse outcome than a degraded session.
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _handleAuthChange(AuthUser? user) async {
    final wasSignedIn = _user != null;
    _user = user;

    if (user != null) {
      if (!wasSignedIn) await _onSignedIn(user);
    } else if (wasSignedIn) {
      await _onSignedOut();
    }

    notifyListeners();
  }

  Future<void> _onSignedIn(AuthUser user) async {
    // Load the display name from `profiles`. A failure here is not a sign-in
    // failure — the old code rethrew and so a Firestore hiccup logged the user
    // out of an otherwise valid session.
    final profile = await _repository.loadProfile();
    if (profile case Ok(:final value)) {
      _user = value;
    }

    await _paymentService.initializeForUser(user.id);
  }

  Future<void> _onSignedOut() async {
    await _paymentService.clearUserData();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  Future<Result<AuthUser>> signUp(
    String email,
    String password,
    String username,
  ) async {
    final result = await _repository.signUp(
      email: email,
      password: password,
      displayName: username,
    );
    if (result case Ok(:final value)) {
      _user = value;
      notifyListeners();
    }
    return result;
  }

  Future<Result<AuthUser>> login(String email, String password) async {
    final result = await _repository.signIn(email: email, password: password);
    if (result case Ok(:final value)) {
      _user = value;
      notifyListeners();
    }
    return result;
  }

  /// Hands off to Google in the system browser.
  ///
  /// An [Ok] here means the browser opened, **not** that anyone is signed in.
  /// The session arrives later through the auth stream, when Android routes
  /// the `com.muscodes.speakwise://login-callback/` redirect back to the app.
  ///
  /// So callers must not do `await signInWithGoogle(); if (isLoggedIn) ...` —
  /// that reads false every time, because the user has not seen the consent
  /// screen yet. Watch [isLoggedIn] via the listener instead, which is exactly
  /// what the existing screens already do while they wait.
  Future<Result<void>> signInWithGoogle() => _repository.signInWithGoogle();

  Future<Result<void>> logout() async {
    final result = await _repository.signOut();
    if (result.isOk) {
      _user = null;
      notifyListeners();
    }
    return result;
  }

  Future<Result<void>> sendPasswordResetEmail(String email) =>
      _repository.sendPasswordReset(email);

  /// Deletes the account and everything it owns (R9.5.2). Irreversible.
  ///
  /// Play requires an in-app deletion path, and §16 bans hard-to-cancel flows,
  /// so this is reachable from Settings in two taps and asks once.
  Future<Result<void>> deleteAccount() async {
    final result = await _repository.deleteAccount();
    if (result.isOk) {
      _user = null;
      await _onSignedOut();
      notifyListeners();
    }
    return result;
  }

  // `setUserAvatar` lived here as a no-op returning a typed failure, for the
  // profile-photo screen alone. Both are gone: `profiles` has no avatar column
  // (§9.5), the screen's "Generate Avatar" option was image generation banned
  // by §16, and nothing else ever called it. R5.3.1 settles what an avatar is
  // in v1 — a generated geometric mark on a partner, not a user photo.

  // ── Usage, local until the gateway lands ───────────────────────────────────
  //
  // Every method below reads PaymentService, never the server. See the class
  // doc: `usage_daily` and `entitlements` are service-role write only, so
  // there is nothing here for a client to read or write yet.

  Future<bool> canSendMessage() async =>
      isPremium ||
      _paymentService.dailyMessageCount < PaymentService.freeDailyMessages;

  Future<bool> canUploadImage() async =>
      isPremium ||
      _paymentService.dailyImageCount < PaymentService.freeDailyImages;

  Future<bool> canSendVoice() async =>
      isPremium ||
      _paymentService.dailyVoiceCount < PaymentService.freeDailyVoice;

  Future<bool> canGenerateImage() async => canUploadImage();

  bool canAccessAllPersonas() => isPremium;

  Future<void> incrementMessageUsage() async {
    if (isPremium) return;
    await _paymentService.incrementMessageCount();
    notifyListeners();
  }

  Future<void> incrementImageUsage() async {
    if (isPremium) return;
    await _paymentService.incrementImageCount();
    notifyListeners();
  }

  Future<void> incrementVoiceUsage() async {
    if (isPremium) return;
    await _paymentService.incrementVoiceCount();
    notifyListeners();
  }
}
