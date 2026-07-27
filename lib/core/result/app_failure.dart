/// The closed set of ways an operation can fail.
///
/// PRD F4: services must not return `null` on failure or swallow exceptions.
/// The UI has to be able to tell offline from rate-limited from
/// quota-exceeded from safety-blocked, because §7.6 requires an error to state
/// its cause *and* its fix, and R11.5 requires every network failure to have a
/// specific message rather than a generic snackbar.
///
/// Sealed, so `switch` over it is exhaustive and adding a new failure mode
/// becomes a compile error at every site that must handle it. That is the
/// point: a new failure type should not be able to fall silently into a
/// default branch reading "Something went wrong".
sealed class AppFailure {
  const AppFailure({this.cause, this.stackTrace});

  /// The underlying exception, if any. For logging — never for display.
  final Object? cause;
  final StackTrace? stackTrace;

  /// A stable identifier for tests and telemetry. Not user-facing.
  String get code;
}

/// No usable network connection.
///
/// Recoverable by definition: R11.5 requires a session started offline to
/// record its transcript locally, compute the local metrics (R4.3.1), and
/// queue the model-generated notes for reconnection. Never present this as
/// losing the user's work.
final class OfflineFailure extends AppFailure {
  const OfflineFailure({super.cause, super.stackTrace});

  @override
  String get code => 'offline';
}

/// The server accepted the request but the caller is going too fast.
///
/// Distinct from [QuotaExceededFailure]: this one resolves by waiting.
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({this.retryAfter, super.cause, super.stackTrace});

  /// How long to wait, when the server says.
  final Duration? retryAfter;

  @override
  String get code => 'rate_limited';
}

/// The user has used their allowance for the period.
///
/// This is the paywall moment (R8.3), not an error. It must never be shown
/// mid-sentence — R8.3 requires finishing the exchange first. Free users hit
/// this on Sessions and still have unlimited Drill Mode (§8, DECISIONS.md D2),
/// so the message is a redirection, never a dead end.
final class QuotaExceededFailure extends AppFailure {
  const QuotaExceededFailure({
    required this.resetsAt,
    this.isUpgradeable = true,
    super.cause,
    super.stackTrace,
  });

  /// When the allowance refills. Server-computed — never trust device time,
  /// which R8.3's acceptance test explicitly probes by changing the clock.
  final DateTime? resetsAt;

  /// False when the ceiling is the fair-use limit in R10.1 rather than the
  /// free tier, in which case upgrading does not help and offering it would
  /// be a dark pattern.
  final bool isUpgradeable;

  @override
  String get code => 'quota_exceeded';
}

/// The provider's safety system refused the request or the response.
///
/// R10.5: show a plain, non-judgemental message and do NOT retry
/// automatically. Retrying a safety block silently is how an app ends up
/// arguing with its own guardrails.
final class SafetyBlockedFailure extends AppFailure {
  const SafetyBlockedFailure({super.cause, super.stackTrace});

  @override
  String get code => 'safety_blocked';
}

/// Global capacity ceiling reached — R10.4's circuit breaker has tripped.
///
/// Separated from [QuotaExceededFailure] because it is not the user's fault
/// and upgrading does not fix it. Given the free-tier limits in
/// `RESEARCH.md` §4.A this will fire in normal operation, so it needs a
/// designed screen rather than an apology.
final class AtCapacityFailure extends AppFailure {
  const AtCapacityFailure({super.cause, super.stackTrace});

  @override
  String get code => 'at_capacity';
}

/// The caller is not authenticated, or the session expired.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({super.cause, super.stackTrace});

  @override
  String get code => 'unauthorized';
}

/// The server rejected the request shape. A bug in our client, not the user's
/// problem — surface it generically but log it loudly.
final class InvalidRequestFailure extends AppFailure {
  const InvalidRequestFailure({this.field, super.cause, super.stackTrace});

  final String? field;

  @override
  String get code => 'invalid_request';
}

/// Local storage failed — Drift, file system, or preferences.
final class StorageFailure extends AppFailure {
  const StorageFailure({super.cause, super.stackTrace});

  @override
  String get code => 'storage';
}

/// A device capability was refused or is unavailable: microphone permission
/// denied, no speech recogniser installed, no TTS voice for the locale.
final class DeviceFailure extends AppFailure {
  const DeviceFailure({required this.capability, super.cause, super.stackTrace});

  final String capability;

  @override
  String get code => 'device_$capability';
}

/// Anything not yet classified.
///
/// Every occurrence of this in production is a gap in the taxonomy above.
/// Treat a rise in `unknown` as a bug report, not as normal background noise.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause, super.stackTrace});

  @override
  String get code => 'unknown';
}
