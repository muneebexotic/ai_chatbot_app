import 'package:flutter/material.dart';

import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/features/session/domain/session_state.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// The bar above the controls: pauses, the noisy-room offer, the quota warning,
/// and failures.
///
/// ## Why these are bars and not snackbars
///
/// CRITIQUE's standing items record it plainly: "An error that is only a
/// snackbar is an error nobody can read." Two sign-up failures on device
/// appeared to do nothing because whatever the controller reported had vanished
/// before the screenshot. During a spoken session it is worse — the user is
/// talking and looking away, and a three-second toast is a message delivered to
/// an empty room.
///
/// Every notice here persists until it is acted on or its cause goes away.
class SessionNotices extends StatelessWidget {
  const SessionNotices({
    super.key,
    required this.state,
    required this.onSwitchToPushToTalk,
    required this.onUseTyping,
    required this.onDismissNoise,
    required this.onResume,
    required this.onDismissFailure,
  });

  final SessionState state;
  final VoidCallback onSwitchToPushToTalk;
  final Future<void> Function() onUseTyping;
  final VoidCallback onDismissNoise;
  final Future<void> Function() onResume;
  final VoidCallback onDismissFailure;

  @override
  Widget build(BuildContext context) {
    // One at a time, most urgent first. Stacking three bars over a transcript
    // would leave nothing to read.
    if (state.phase == SessionPhase.paused) {
      return _PausedNotice(
        reason: state.interruption,
        onResume: onResume,
      );
    }
    if (state.failure != null) {
      return _FailureNotice(
        failure: state.failure!,
        onDismiss: onDismissFailure,
      );
    }
    if (state.isEnvironmentNoisy) {
      return _NoisyNotice(
        onSwitchToPushToTalk: onSwitchToPushToTalk,
        onUseTyping: onUseTyping,
        onDismiss: onDismissNoise,
      );
    }
    if (state.usage?.shouldWarn ?? false) {
      return _RemainingNotice(usage: state.usage!);
    }
    return const SizedBox.shrink();
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: Space.md),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.cardAll,
        border: Border.all(color: accent ?? colors.line),
      ),
      child: child,
    );
  }
}

/// R4.2.6: each interruption "pauses the session and offers resume; nothing is
/// lost."
class _PausedNotice extends StatelessWidget {
  const _PausedNotice({required this.reason, required this.onResume});

  final InterruptionReason? reason;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // §7.6 requires an error to state its cause and its fix, so each reason
    // gets its own sentence rather than a shared "Session paused".
    final cause = switch (reason) {
      InterruptionReason.incomingCall => l10n.sessionInterruptedCall,
      InterruptionReason.backgrounded => l10n.sessionInterruptedBackground,
      InterruptionReason.headphonesDisconnected =>
        l10n.sessionInterruptedHeadphones,
      InterruptionReason.networkLost => l10n.sessionInterruptedNetwork,
      InterruptionReason.microphoneLost => l10n.sessionInterruptedMicrophone,
      null => l10n.sessionStatePaused,
    };

    return _Band(
      accent: colors.signal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cause, style: AppTypography.body2.copyWith(color: colors.ink)),
          const SizedBox(height: Space.xxs),
          Text(
            l10n.sessionNothingLost,
            style: AppTypography.micro.copyWith(color: colors.muted),
          ),
          const SizedBox(height: Space.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onResume(),
              child: Text(
                l10n.sessionResume,
                style: AppTypography.label.copyWith(color: colors.signal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// R4.2.2's noisy-room suggestion, plus P8's third option.
class _NoisyNotice extends StatelessWidget {
  const _NoisyNotice({
    required this.onSwitchToPushToTalk,
    required this.onUseTyping,
    required this.onDismiss,
  });

  final VoidCallback onSwitchToPushToTalk;
  final Future<void> Function() onUseTyping;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return _Band(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sessionNoisyTitle,
            style: AppTypography.body2.copyWith(color: colors.ink),
          ),
          const SizedBox(height: Space.xs),
          // Three options and no default. R4.2.2 is explicit: "a non-blocking
          // suggestion, never a forced switch". "Keep going" is listed as a
          // real choice rather than a dismissal X, because carrying on in a
          // loud room is often the right answer and the app does not know
          // better than the person in the room.
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xxs,
            children: [
              TextButton(
                onPressed: onSwitchToPushToTalk,
                child: Text(
                  l10n.sessionNoisySwitch,
                  style: AppTypography.label.copyWith(color: colors.signal),
                ),
              ),
              TextButton(
                onPressed: () => onUseTyping(),
                child: Text(
                  l10n.sessionNoisyType,
                  style: AppTypography.label.copyWith(color: colors.signal),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  l10n.sessionNoisyDismiss,
                  style: AppTypography.label.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// §8's remaining spoken minutes, as the server reported them (F2).
class _RemainingNotice extends StatelessWidget {
  const _RemainingNotice({required this.usage});

  final SessionUsage usage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return _Band(
      child: Text(
        // Rounded up: telling somebody they have "1 minute left" when 119
        // seconds remain is a small lie in the app's favour.
        l10n.sessionRemaining((usage.remainingSeconds / 60).ceil()),
        style: AppTypography.micro.copyWith(color: colors.muted),
      ),
    );
  }
}

class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.failure, required this.onDismiss});

  final AppFailure failure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // R11.5: a specific message per failure, never a generic snackbar. The
    // session ones reuse the copy that already exists for each cause.
    final message = switch (failure) {
      OfflineFailure() => l10n.sessionInterruptedNetwork,
      QuotaExceededFailure() => l10n.sessionQuotaReachedTitle,
      AtCapacityFailure() => l10n.sessionQuotaReachedBody,
      DeviceFailure() => l10n.sessionInterruptedMicrophone,
      _ => l10n.sessionStatePaused,
    };

    return _Band(
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.body2.copyWith(color: colors.ink),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 18, color: colors.muted),
          ),
        ],
      ),
    );
  }
}
