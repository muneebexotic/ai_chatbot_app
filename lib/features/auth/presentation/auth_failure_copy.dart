import 'package:ai_chatbot_app/core/result/app_failure.dart';

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
/// leaves the person guessing what to do. Every string below names something
/// the reader can act on.
///
/// Plain, direct, a little dry. No exclamation marks, no emoji, no apologising
/// for the software's own behaviour.
///
/// ## Known debt
///
/// R11.7 requires every user-facing string to come from an ARB file in
/// `l10n/`, and there is no `l10n/` yet. Centralising them here is the step
/// that makes that migration a single file's worth of work instead of a hunt
/// through controllers. Tracked as unmet, not solved.
String authFailureMessage(AppFailure failure) {
  return switch (failure) {
    AuthFailure(reason: AuthFailureReason.invalidCredentials) =>
      'That email and password do not match. Check both, or reset your '
          'password.',

    AuthFailure(reason: AuthFailureReason.emailAlreadyRegistered) =>
      'That email already has an account. Sign in instead, or reset the '
          'password.',

    AuthFailure(reason: AuthFailureReason.weakPassword) =>
      'That password is too short. Use at least eight characters.',

    AuthFailure(reason: AuthFailureReason.emailNotConfirmed) =>
      'Check your email and open the confirmation link, then sign in.',

    AuthFailure(reason: AuthFailureReason.invalidEmail) =>
      'That does not look like an email address.',

    // Reused for "Google sign-in is not available yet". Honest about the
    // state of the world rather than pretending the tap did nothing.
    AuthFailure(reason: AuthFailureReason.signUpDisabled) =>
      'Google sign-in is not available yet. Use an email address and password.',

    OfflineFailure() =>
      'No internet connection. Your details are not sent until you reconnect.',

    RateLimitedFailure(:final retryAfter) => retryAfter == null
        ? 'Too many attempts. Wait a minute and try again.'
        : 'Too many attempts. Try again in ${retryAfter.inSeconds} seconds.',

    UnauthorizedFailure() => 'Your session ended. Sign in again.',

    InvalidRequestFailure() =>
      'That did not go through. Check the details and try again.',

    StorageFailure() =>
      'Could not save to this device. Check your available storage.',

    DeviceFailure(:final capability) =>
      'This device would not allow $capability.',

    // These three cannot arise from an auth call today. They are listed rather
    // than defaulted because AppFailure is sealed: if a new failure type is
    // added, this switch stops compiling and someone has to decide what the
    // user reads, instead of inheriting a generic line by accident.
    QuotaExceededFailure() => 'You have used your allowance for today.',
    SafetyBlockedFailure() => 'That request was refused.',
    AtCapacityFailure() =>
      'The service is at capacity right now. Try again shortly.',

    UnknownFailure() =>
      'Something failed and we do not yet know what. Try again; if it keeps '
          'happening, it is a bug worth reporting.',
  };
}
