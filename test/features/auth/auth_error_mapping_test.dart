import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/features/auth/data/auth_repository.dart';

/// Verifies that Supabase auth errors land on the right [AppFailure].
///
/// This is the one piece of real logic in `AuthRepository`; everything else
/// delegates to the SDK. It is worth testing directly because PRD F4 and
/// R11.5 require the UI to distinguish these cases and say something specific
/// for each — a mapper that quietly collapses everything to `unknown` would
/// satisfy the type system and defeat the requirement.
void main() {
  AppFailure map(String code, {String message = 'x', String? status}) =>
      AuthRepository.mapAuthException(
        AuthException(message, statusCode: status, code: code),
        StackTrace.empty,
      );

  group('Supabase error code → AppFailure', () {
    test('invalid_credentials', () {
      final f = map('invalid_credentials');
      expect(f, isA<AuthFailure>());
      expect((f as AuthFailure).reason, AuthFailureReason.invalidCredentials);
      expect(f.code, 'auth_invalidCredentials');
    });

    test('user_already_exists and email_exists both mean registered', () {
      for (final code in ['user_already_exists', 'email_exists']) {
        expect(
          (map(code) as AuthFailure).reason,
          AuthFailureReason.emailAlreadyRegistered,
          reason: '$code should map to emailAlreadyRegistered',
        );
      }
    });

    test('weak_password', () {
      expect(
        (map('weak_password') as AuthFailure).reason,
        AuthFailureReason.weakPassword,
      );
    });

    test('email_not_confirmed', () {
      expect(
        (map('email_not_confirmed') as AuthFailure).reason,
        AuthFailureReason.emailNotConfirmed,
      );
    });

    test('signup_disabled', () {
      expect(
        (map('signup_disabled') as AuthFailure).reason,
        AuthFailureReason.signUpDisabled,
      );
    });

    test('rate limit codes map to RateLimitedFailure, not AuthFailure', () {
      // Waiting fixes these; no copy about credentials would make sense.
      for (final code in [
        'over_request_rate_limit',
        'over_email_send_rate_limit',
      ]) {
        expect(map(code), isA<RateLimitedFailure>(), reason: code);
      }
    });
  });

  group('fallbacks when there is no code', () {
    test('HTTP 429 is rate limiting', () {
      expect(
        AuthRepository.mapAuthException(
          AuthException('too many', statusCode: '429'),
          StackTrace.empty,
        ),
        isA<RateLimitedFailure>(),
      );
    });

    test('HTTP 401 is unauthorized', () {
      expect(
        AuthRepository.mapAuthException(
          AuthException('nope', statusCode: '401'),
          StackTrace.empty,
        ),
        isA<UnauthorizedFailure>(),
      );
    });

    test('message text is matched only as a last resort', () {
      final f = AuthRepository.mapAuthException(
        AuthException('Invalid login credentials'),
        StackTrace.empty,
      );
      expect((f as AuthFailure).reason, AuthFailureReason.invalidCredentials);
    });

    test('an unrecognised error is UnknownFailure, not a wrong guess', () {
      // Guessing here would be worse than admitting ignorance: the UI shows a
      // specific fix per failure type, and a confidently wrong fix wastes more
      // of the user's time than a generic message.
      expect(
        AuthRepository.mapAuthException(
          AuthException('something new the server started saying'),
          StackTrace.empty,
        ),
        isA<UnknownFailure>(),
      );
    });
  });

  group('taxonomy invariants', () {
    test('every reason produces a distinct, stable code string', () {
      final codes = AuthFailureReason.values
          .map((r) => AuthFailure(r).code)
          .toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes, everyElement(startsWith('auth_')));
    });

    test('invalidCredentials does not distinguish wrong password from no such '
        'account', () {
      // Both paths must land on the same reason. If a future change splits
      // them, the app gains an account-enumeration oracle: an anonymous caller
      // could learn which email addresses have accounts.
      final wrongPassword = map('invalid_credentials');
      final noSuchUser = AuthRepository.mapAuthException(
        AuthException('Invalid login credentials'),
        StackTrace.empty,
      );
      expect(
        (wrongPassword as AuthFailure).reason,
        (noSuchUser as AuthFailure).reason,
      );
    });
  });
}
