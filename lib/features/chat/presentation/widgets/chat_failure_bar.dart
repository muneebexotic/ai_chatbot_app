import 'package:flutter/material.dart';

import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// What the user reads when a turn does not arrive.
///
/// R11.5: "Every network failure has a specific message, never a generic
/// snackbar." §7.6: "Errors state the cause and the fix."
///
/// A bar above the composer rather than a snackbar, for three reasons: it does
/// not cover the transcript, it does not time out before it has been read, and
/// it can carry an action. A snackbar that says "no internet" and vanishes in
/// four seconds has told the user nothing they can act on.
///
/// Failures are not all the same shape, and the switch below is where that
/// shows. Offline offers a retry. Quota is the paywall moment (R8.3) and offers
/// an upgrade **only when upgrading would actually help** — a Pro user at the
/// R10.1 fair-use ceiling is told to wait, because selling them something that
/// changes nothing is the dark pattern §16 forbids. A safety block offers
/// nothing at all: R10.5 requires a plain, non-judgemental message and no
/// automatic retry.
class ChatFailureBar extends StatelessWidget {
  const ChatFailureBar({
    super.key,
    required this.failure,
    required this.onDismiss,
    required this.onRetry,
    required this.onUpgrade,
  });

  final AppFailure failure;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final (message, action) = switch (failure) {
      OfflineFailure() => (l10n.chatErrorOffline, _Action.retry),
      AtCapacityFailure() => (l10n.chatErrorAtCapacity, _Action.retry),
      SafetyBlockedFailure() => (l10n.chatErrorSafetyBlocked, _Action.none),
      UnauthorizedFailure() => (l10n.chatErrorSignedOut, _Action.none),
      AuthFailure(reason: AuthFailureReason.emailNotConfirmed) => (
        l10n.chatErrorEmailNotConfirmed,
        _Action.none,
      ),
      RateLimitedFailure(:final retryAfter) => (
        retryAfter == null
            ? l10n.chatErrorRateLimited
            : l10n.chatErrorRateLimitedFor(retryAfter.inMinutes + 1),
        _Action.none,
      ),
      QuotaExceededFailure(:final isUpgradeable) => (
        isUpgradeable ? l10n.chatErrorQuotaFree : l10n.chatErrorQuotaFairUse,
        isUpgradeable ? _Action.upgrade : _Action.none,
      ),
      InvalidRequestFailure() => (l10n.chatErrorInvalid, _Action.none),
      _ => (l10n.chatErrorUnknown, _Action.retry),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.label.copyWith(color: colors.ink),
            ),
          ),
          if (action == _Action.retry)
            TextButton(
              onPressed: onRetry,
              child: Text(
                l10n.chatRetry,
                style: AppTypography.label.copyWith(color: colors.signal),
              ),
            ),
          if (action == _Action.upgrade)
            TextButton(
              onPressed: onUpgrade,
              child: Text(
                l10n.chatSeePro,
                style: AppTypography.label.copyWith(color: colors.signal),
              ),
            ),
          IconButton(
            onPressed: onDismiss,
            iconSize: 18,
            tooltip: l10n.chatDismiss,
            icon: Icon(Icons.close_rounded, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

enum _Action { none, retry, upgrade }
