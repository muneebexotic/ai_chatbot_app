import 'package:flutter_test/flutter_test.dart';

import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';

void main() {
  group('Result', () {
    test('Ok carries its value and reports isOk', () {
      const result = Ok<int>(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err carries its failure and reports isErr', () {
      const failure = OfflineFailure();
      const result = Err<int>(failure);
      expect(result.isErr, isTrue);
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
    });

    test('fold runs exactly one branch', () {
      expect(const Ok<int>(1).fold(ok: (v) => 'ok$v', err: (f) => 'err'), 'ok1');
      expect(
        const Err<int>(OfflineFailure()).fold(
          ok: (v) => 'ok',
          err: (f) => 'err:${f.code}',
        ),
        'err:offline',
      );
    });

    test('map transforms Ok and passes Err through untouched', () {
      expect(const Ok<int>(2).map((v) => v * 3), const Ok<int>(6));

      const failure = RateLimitedFailure();
      final mapped = const Err<int>(failure).map((v) => v * 3);
      expect(mapped.isErr, isTrue);
      expect(mapped.failureOrNull, same(failure));
    });

    test('flatMap does not nest Results', () {
      final chained = const Ok<int>(2).flatMap((v) => Ok<String>('v$v'));
      expect(chained, const Ok<String>('v2'));

      final shortCircuited = const Err<int>(
        OfflineFailure(),
      ).flatMap((v) => Ok<String>('unreachable'));
      expect(shortCircuited.isErr, isTrue);
    });

    test('getOrElse returns the fallback only for Err', () {
      expect(const Ok<int>(5).getOrElse(99), 5);
      expect(const Err<int>(OfflineFailure()).getOrElse(99), 99);
    });

    group('guard', () {
      test('captures a return value as Ok', () {
        expect(Result<int>.guard(() => 7), const Ok<int>(7));
      });

      test('converts a throw into Err, defaulting to UnknownFailure', () {
        final result = Result<int>.guard(() => throw StateError('boom'));
        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<UnknownFailure>());
        expect(result.failureOrNull!.cause, isA<StateError>());
      });

      test('uses onError to map onto the failure taxonomy', () {
        final result = Result<int>.guard(
          () => throw StateError('boom'),
          onError: (e, s) => StorageFailure(cause: e, stackTrace: s),
        );
        expect(result.failureOrNull, isA<StorageFailure>());
        expect(result.failureOrNull!.code, 'storage');
      });

      test('does not swallow the stack trace', () {
        final result = Result<int>.guard(() => throw StateError('boom'));
        expect(result.failureOrNull!.stackTrace, isNotNull);
      });
    });

    group('guardAsync', () {
      test('captures a resolved value as Ok', () async {
        expect(await Result.guardAsync<int>(() async => 7), const Ok<int>(7));
      });

      test('converts a rejection into Err', () async {
        final result = await Result.guardAsync<int>(
          () async => throw StateError('boom'),
          onError: (e, s) => OfflineFailure(cause: e, stackTrace: s),
        );
        expect(result.failureOrNull, isA<OfflineFailure>());
      });
    });

    test('equality is by value, so Results compare cleanly in tests', () {
      expect(const Ok<int>(1), const Ok<int>(1));
      expect(const Ok<int>(1), isNot(const Ok<int>(2)));
      expect(const Ok<int>(1).hashCode, const Ok<int>(1).hashCode);
    });
  });

  group('AppFailure taxonomy', () {
    test('every failure exposes a distinct, stable code', () {
      final failures = <AppFailure>[
        const OfflineFailure(),
        const RateLimitedFailure(),
        QuotaExceededFailure(resetsAt: DateTime(2026)),
        const SafetyBlockedFailure(),
        const AtCapacityFailure(),
        const UnauthorizedFailure(),
        const InvalidRequestFailure(),
        const StorageFailure(),
        const DeviceFailure(capability: 'microphone'),
        const UnknownFailure(),
      ];

      final codes = failures.map((f) => f.code).toList();
      expect(
        codes.toSet().length,
        codes.length,
        reason: 'codes are used by telemetry and tests; they must be unique',
      );
      expect(codes, everyElement(isNotEmpty));
    });

    test('DeviceFailure namespaces its code by capability', () {
      expect(
        const DeviceFailure(capability: 'microphone').code,
        'device_microphone',
      );
    });

    test('QuotaExceededFailure can say upgrading will not help', () {
      // R10.1's fair-use ceiling sits above the Pro tier, so offering an
      // upgrade there would be a dark pattern (PRD §16).
      const fairUse = QuotaExceededFailure(
        resetsAt: null,
        isUpgradeable: false,
      );
      expect(fairUse.isUpgradeable, isFalse);
    });

    test('switch over AppFailure is exhaustive', () {
      // If this stops compiling, a new failure type was added without every
      // handling site being updated -- which is exactly what sealing buys.
      String describe(AppFailure f) => switch (f) {
        OfflineFailure() => 'offline',
        RateLimitedFailure() => 'rate',
        QuotaExceededFailure() => 'quota',
        SafetyBlockedFailure() => 'safety',
        AtCapacityFailure() => 'capacity',
        UnauthorizedFailure() => 'not signed in',
        AuthFailure() => 'sign-in refused',
        InvalidRequestFailure() => 'request',
        StorageFailure() => 'storage',
        DeviceFailure() => 'device',
        UnknownFailure() => 'unknown',
      };

      expect(describe(const OfflineFailure()), 'offline');
      expect(describe(const AtCapacityFailure()), 'capacity');
      expect(
        describe(const AuthFailure(AuthFailureReason.invalidCredentials)),
        'sign-in refused',
      );
    });

    test('AuthFailure is distinct from UnauthorizedFailure', () {
      // "You are not signed in" and "your sign-in attempt was refused, and
      // here is why" need different copy and different next steps. Collapsing
      // them is how an app ends up telling someone who typed the wrong
      // password that their session expired.
      expect(
        const AuthFailure(AuthFailureReason.invalidCredentials),
        isNot(isA<UnauthorizedFailure>()),
      );
      expect(
        const AuthFailure(AuthFailureReason.weakPassword).code,
        isNot(const UnauthorizedFailure().code),
      );
    });
  });
}
