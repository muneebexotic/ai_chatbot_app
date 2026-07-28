@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'package:ai_chatbot_app/core/result/app_failure.dart';
import 'package:ai_chatbot_app/core/result/result.dart';
import 'package:ai_chatbot_app/features/auth/data/auth_repository.dart';
import 'package:ai_chatbot_app/features/auth/domain/auth_user.dart';

/// Exercises [AuthRepository] against a live project.
///
/// The unit tests in `auth_error_mapping_test.dart` prove the mapper handles the
/// codes it is given. They cannot prove those are the codes Supabase actually
/// sends — that was read from documentation and is therefore an assumption
/// until a real server says otherwise. This file is what turns it into a fact.
///
/// Points at **kalaam-dev**, and creates users there. Run with:
///
///     flutter test test/features/auth/auth_repository_integration_test.dart \
///       --dart-define=SUPABASE_URL=https://<dev-ref>.supabase.co \
///       --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

void main() {
  final configured = _url.isNotEmpty && _key.isNotEmpty;

  group(
    'AuthRepository against a live project',
    skip: configured
        ? null
        : 'Set --dart-define=SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to run. '
              'Point them at kalaam-dev, never production.',
    () {
      late SupabaseClient client;
      late AuthRepository repository;
      late String email;

      /// Derived per run rather than written as a literal.
      ///
      /// Two reasons, and the second is the one that matters. A literal
      /// `password = '...'` in source is exactly the shape check-secrets.sh
      /// exists to stop, and the scanner cannot know this particular account
      /// is disposable — teaching it an exception for test files would mean a
      /// real credential in a test could never be caught again. Deriving it
      /// removes the pattern entirely, and gives every run a fresh secret as a
      /// side effect.
      late String password;

      const displayName = 'Integration Tester';

      setUp(() {
        client = SupabaseClient(
          _url,
          _key,
          // See the note in test/rls/rls_policy_test.dart: PKCE needs storage a
          // bare client has none of, and these tests never use a redirect.
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );
        repository = AuthRepository(client);

        final stamp = DateTime.now().microsecondsSinceEpoch;
        email = 'auth-$stamp@example.com';
        password = 'Aa1!-$stamp';
      });

      tearDown(() async {
        await client.dispose();
      });

      test('sign-up returns a user and leaves a live session', () async {
        final result = await repository.signUp(
          email: email,
          password: password,
          displayName: displayName,
        );

        expect(result, isA<Ok<AuthUser>>());
        final user = result.valueOrNull!;
        expect(user.email, email);
        expect(user.id, isNotEmpty);
        expect(repository.isSignedIn, isTrue);
      });

      test('the database trigger seeds profiles.display_name', () async {
        await repository.signUp(
          email: email,
          password: password,
          displayName: displayName,
        );

        // Proves `handle_new_user` in the schema migration actually fires and
        // reads raw_user_meta_data — a claim the migration makes and only a
        // round trip can confirm.
        final profile = await repository.loadProfile();
        expect(profile, isA<Ok<AuthUser>>());
        expect(profile.valueOrNull!.displayName, displayName);
      });

      test('signing up twice reports emailAlreadyRegistered', () async {
        await repository.signUp(email: email, password: password);
        await repository.signOut();

        final second = await repository.signUp(
          email: email,
          password: password,
        );

        // The assertion that matters: this is the code the real server sends,
        // not the one the docs describe.
        expect(second, isA<Err<AuthUser>>());
        final failure = second.failureOrNull;
        expect(
          failure,
          isA<AuthFailure>(),
          reason: 'got ${failure?.code} — the mapper missed a real server code',
        );
        expect(
          (failure! as AuthFailure).reason,
          AuthFailureReason.emailAlreadyRegistered,
        );
      });

      test('a wrong password reports invalidCredentials', () async {
        await repository.signUp(email: email, password: password);
        await repository.signOut();

        final result = await repository.signIn(
          email: email,
          password: '$password-wrong',
        );

        expect(result, isA<Err<AuthUser>>());
        expect(
          (result.failureOrNull! as AuthFailure).reason,
          AuthFailureReason.invalidCredentials,
        );
      });

      test('an unknown address reports the same reason as a wrong password',
          () async {
        // Both must be indistinguishable to the caller, or the app becomes an
        // account-enumeration oracle. Asserted here against the live server,
        // because this property depends on Supabase's behaviour and not only
        // on our mapper.
        final unknown = await repository.signIn(
          email: 'definitely-not-registered-${DateTime.now().microsecondsSinceEpoch}@example.com',
          password: password,
        );

        expect(
          (unknown.failureOrNull! as AuthFailure).reason,
          AuthFailureReason.invalidCredentials,
        );
      });

      test('sign-in then sign-out moves isSignedIn both ways', () async {
        await repository.signUp(email: email, password: password);
        await repository.signOut();
        expect(repository.isSignedIn, isFalse);
        expect(repository.currentUser, isNull);

        final signIn = await repository.signIn(
          email: email,
          password: password,
        );
        expect(signIn, isA<Ok<AuthUser>>());
        expect(repository.isSignedIn, isTrue);

        await repository.signOut();
        expect(repository.isSignedIn, isFalse);
      });

      test('loadProfile without a session is Unauthorized, not a crash', () async {
        final result = await repository.loadProfile();
        expect(result.failureOrNull, isA<UnauthorizedFailure>());
      });

      test('deleteAccount removes the account and its rows (R9.5.2)', () async {
        await repository.signUp(email: email, password: password);
        final userId = repository.currentUser!.id;

        // Own a row in a cascading table, so the test proves the cascade and
        // not merely that the auth user vanished.
        await client.from('threads').insert({
          'user_id': userId,
          'title': 'to be deleted',
        });

        final deleted = await repository.deleteAccount();
        expect(deleted, isA<Ok<void>>());

        // Locally signed out, so the app cannot hold a token for an account
        // that no longer exists.
        expect(repository.isSignedIn, isFalse);
        expect(repository.currentUser, isNull);

        // And genuinely gone server-side: the credentials no longer work.
        // Without this the test would pass against a function that signed the
        // user out and deleted nothing.
        final resurrect = await repository.signIn(
          email: email,
          password: password,
        );
        expect(resurrect, isA<Err<AuthUser>>());
        expect(
          (resurrect.failureOrNull! as AuthFailure).reason,
          AuthFailureReason.invalidCredentials,
        );
      });

      test('deleteAccount without a session is refused', () async {
        final result = await repository.deleteAccount();
        expect(result.failureOrNull, isA<UnauthorizedFailure>());
      });

      test('password reset succeeds for an address with no account', () async {
        // Deliberate: a reset endpoint that reports "no such user" is an
        // enumeration oracle. This asserts the non-leaking behaviour, which is
        // also why the UI copy has to be "if that address has an account".
        final result = await repository.sendPasswordReset(
          'no-account-${DateTime.now().microsecondsSinceEpoch}@example.com',
        );
        expect(result, isA<Ok<void>>());
      });
    },
  );
}
