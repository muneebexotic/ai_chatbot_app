import 'package:flutter/material.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/features/session/domain/session_settings.dart';
import 'package:speakwise/features/session/domain/session_state.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// R4.2.1's "three controls: mute, mode toggle, end session".
///
/// Exactly three. The temptation on a screen like this is a settings gear, a
/// partner switcher, a skip button — and every one of them is a reason to look
/// at the phone during a conversation the user is supposed to be having out
/// loud. R4.2.1 says "single-purpose", and three controls is what that means.
///
/// The typing fallback (PROPOSALS P8) replaces the row rather than adding to
/// it: while typing, mute and the mode toggle have nothing to act on.
class SessionControls extends StatelessWidget {
  const SessionControls({
    super.key,
    required this.state,
    required this.onToggleMute,
    required this.onToggleMode,
    required this.onEnd,
    required this.onSendTyped,
    required this.onBackToSpeaking,
  });

  final SessionState state;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleMode;
  final Future<void> Function() onEnd;
  final Future<void> Function(String) onSendTyped;
  final Future<void> Function() onBackToSpeaking;

  @override
  Widget build(BuildContext context) {
    if (state.isTypingFallback) {
      return _TypingComposer(
        onSend: onSendTyped,
        onBackToSpeaking: onBackToSpeaking,
        isBusy: state.phase == SessionPhase.thinking,
      );
    }

    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: state.isMuted ? l10n.sessionUnmute : l10n.sessionMute,
            isActive: state.isMuted,
            onPressed: onToggleMute,
          ),
          _ControlButton(
            icon: state.inputMode == SessionInputMode.handsFree
                ? Icons.hearing_rounded
                : Icons.touch_app_rounded,
            label: state.inputMode == SessionInputMode.handsFree
                ? l10n.sessionModeHandsFree
                : l10n.sessionModePushToTalk,
            onPressed: onToggleMode,
          ),
          _ControlButton(
            icon: Icons.stop_rounded,
            label: l10n.sessionEnd,
            isDestructive: true,
            onPressed: () => onEnd(),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // `live` red is reserved for a hot microphone (R7.1.1) and must never be
    // decorative, so End is `ink` on a bordered surface rather than red. It is
    // distinguished by shape and position, not by alarm.
    final tint = isActive ? colors.signal : colors.ink;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: Radii.fullAll,
        onTap: onPressed,
        child: Container(
          // §11.6: at least 48dp. These are pressed by someone who is talking
          // and not looking closely.
          constraints: const BoxConstraints(
            minWidth: Touch.minTarget + 24,
            minHeight: Touch.minTarget + 12,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.xs,
          ),
          decoration: BoxDecoration(
            color: isActive ? colors.surfaceRaised : Colors.transparent,
            borderRadius: Radii.fullAll,
            border: Border.all(
              color: isDestructive ? colors.line : (isActive ? colors.signal : colors.line),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: tint),
              const SizedBox(height: Space.xxs),
              Text(
                label,
                style: AppTypography.micro.copyWith(color: colors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PROPOSALS P8: keep the session, switch to typing, keep the report.
class _TypingComposer extends StatefulWidget {
  const _TypingComposer({
    required this.onSend,
    required this.onBackToSpeaking,
    required this.isBusy,
  });

  final Future<void> Function(String) onSend;
  final Future<void> Function() onBackToSpeaking;
  final bool isBusy;

  @override
  State<_TypingComposer> createState() => _TypingComposerState();
}

class _TypingComposerState extends State<_TypingComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || widget.isBusy) return;
    _controller.clear();
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isBusy,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: AppTypography.body2.copyWith(color: colors.ink),
                  decoration: InputDecoration(
                    hintText: l10n.sessionTypeHint,
                    hintStyle: AppTypography.body2.copyWith(color: colors.muted),
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              IconButton(
                onPressed: widget.isBusy ? null : _send,
                icon: Icon(Icons.arrow_upward_rounded, color: colors.signal),
                tooltip: l10n.sessionTypeHint,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => widget.onBackToSpeaking(),
              child: Text(
                l10n.sessionBackToSpeaking,
                style: AppTypography.label.copyWith(color: colors.signal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
