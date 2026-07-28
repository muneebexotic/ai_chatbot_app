import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// Turns an [AppFailure] into something to show a person (PRD §7.6, R11.5).
///
/// One place, not three. The old controllers each formatted their own error
/// text from a caught exception's `toString()`, which is how a user ended up
/// reading "Exception: AuthException: ..." on a sign-in screen.
///
/// ## The rule these follow
///
/// §7.6: an error states its **cause and its fix**. "Something went wrong" has
/// neither. So does "invalid credentials" on its own — it names a cause and
/// leaves the person guessing what to do. Every string behind these keys names
/// something the reader can act on.
///
/// Plain, direct, a little dry. No exclamation marks, no emoji, no apologising
/// for the software's own behaviour.
///
/// ## Where the words live
///
/// In `lib/l10n/app_en.arb`, per R11.7 — not here. This file is now a mapping
/// from a failure type to a key, which is the part that has to stay exhaustive;
/// the copy is data. That split is the whole point of the requirement: adding
/// Urdu should be a second ARB file and nothing else.
///
/// [l10n] is passed in rather than read from a `BuildContext` inside, because
/// this is called from controllers as well as widgets and §9.1 keeps context
/// out of anything that is not a widget.
String authFailureMessage(AppLocalizations l10n, AppFailure failure) {
  return switch (failure) {
    AuthFailure(reason: AuthFailureReason.invalidCredentials) =>
      l10n.authInvalidCredentials,

    AuthFailure(reason: AuthFailureReason.emailAlreadyRegistered) =>
      l10n.authEmailAlreadyRegistered,

    AuthFailure(reason: AuthFailureReason.weakPassword) => l10n.authWeakPassword,

    AuthFailure(reason: AuthFailureReason.emailNotConfirmed) =>
      l10n.authEmailNotConfirmed,

    AuthFailure(reason: AuthFailureReason.invalidEmail) => l10n.authInvalidEmail,

    // Reused for "Google sign-in is not available yet". Honest about the
    // state of the world rather than pretending the tap did nothing.
    AuthFailure(reason: AuthFailureReason.signUpDisabled) =>
      l10n.authGoogleUnavailable,

    OfflineFailure() => l10n.failureOffline,

    RateLimitedFailure(:final retryAfter) => retryAfter == null
        ? l10n.failureRateLimited
        : l10n.failureRateLimitedFor(retryAfter.inSeconds),

    UnauthorizedFailure() => l10n.failureUnauthorized,

    InvalidRequestFailure() => l10n.failureInvalidRequest,

    StorageFailure() => l10n.failureStorage,

    DeviceFailure(:final capability) => l10n.failureDevice(capability),

    // These three cannot arise from an auth call today. They are listed rather
    // than defaulted because AppFailure is sealed: if a new failure type is
    // added, this switch stops compiling and someone has to decide what the
    // user reads, instead of inheriting a generic line by accident.
    QuotaExceededFailure() => l10n.failureQuotaExceeded,
    SafetyBlockedFailure() => l10n.failureSafetyBlocked,
    AtCapacityFailure() => l10n.failureAtCapacity,

    UnknownFailure() => l10n.failureUnknown,
  };
}
