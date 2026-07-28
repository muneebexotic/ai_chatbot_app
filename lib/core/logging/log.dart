import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Structured logging that compiles to nothing in release builds.
///
/// PRD §2.2 and §16: no `print()` in release. The old codebase had 182 bare
/// `print()` calls, many with emoji prefixes, several printing Firebase UIDs
/// straight to logcat where any app holding `READ_LOGS` — or anyone with adb —
/// could read them (`SECURITY-REMEDIATION.md` §1.5).
///
/// Every method here is guarded by [kDebugMode], which is a compile-time
/// constant. In a release build the guard is const-folded to `false` and the
/// tree-shaker removes both the call and its arguments, so string
/// interpolation in a log line costs nothing in production.
///
/// Uses `dart:developer`'s [developer.log] rather than `print` so that output
/// carries a level and a name, is grouped by source in DevTools, and is not
/// truncated at ~1KB the way `print` is on Android.
abstract final class Log {
  const Log._();

  /// Verbose detail. Off in release. Use for tracing flow while debugging.
  static void d(String message, {String name = 'speakwise'}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: _Level.debug);
    }
  }

  /// Notable but expected events: a session started, a route pushed.
  static void i(String message, {String name = 'speakwise'}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: _Level.info);
    }
  }

  /// Something recoverable went wrong and the user may notice.
  static void w(String message, {String name = 'speakwise', Object? error}) {
    if (kDebugMode) {
      developer.log(message, name: name, level: _Level.warning, error: error);
    }
  }

  /// Something failed. Pass the [error] and [stackTrace] rather than
  /// interpolating them, so DevTools can render them properly.
  ///
  /// Deliberately still debug-only. Release-build error reporting is a
  /// separate concern (PRD §12 lists Sentry/PostHog free tiers, or a local
  /// error log) and must not be smuggled in through the logger, because that
  /// is how personal data ends up leaving the device by accident.
  static void e(
    String message, {
    String name = 'speakwise',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      developer.log(
        message,
        name: name,
        level: _Level.error,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Matches the `package:logging` level convention that `dart:developer`
/// expects, without taking the dependency.
abstract final class _Level {
  static const int debug = 500;
  static const int info = 800;
  static const int warning = 900;
  static const int error = 1000;
}
