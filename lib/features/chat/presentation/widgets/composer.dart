import 'package:flutter/material.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/tokens/app_metrics.dart';
import 'package:ai_chatbot_app/design/tokens/app_typography.dart';
import 'package:ai_chatbot_app/l10n/app_localizations.dart';

/// The message input.
///
/// Replaces `message_input_field.dart`, which was 721 lines and carried an
/// attachment menu, a voice button, an image picker sheet, and three hardcoded
/// `Colors.white` values that CRITIQUE F7 flagged as latent contrast bugs.
/// What is left is a field and a send button, because that is what typed chat
/// needs — §5.1 calls typed chat "the quiet half of the product", and the
/// spoken half gets its own full screen in Milestone 4 rather than a button
/// squeezed in beside a text field.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.enabled,
  });

  final void Function(String text) onSend;

  /// False while a reply is streaming. The field stays visible and editable —
  /// only sending is held — so a user can compose their next turn while the
  /// partner is still answering.
  final bool enabled;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    // Keep focus: a user sending several short turns should not have to tap
    // back into the field every time.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final canSend = _hasText && widget.enabled;

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        // A hairline, not a shadow (§7.3).
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: AppTypography.body2.copyWith(color: colors.ink),
                  // Multi-line without a fixed height: the field grows to six
                  // lines and then scrolls, so a long message is composable
                  // without the composer eating the transcript.
                  maxLines: 6,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.chatComposerHint,
                    hintStyle: AppTypography.body2.copyWith(color: colors.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: Space.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              _SendButton(onPressed: canSend ? _submit : null),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amber when it will do something, hairline outline when it will not.
///
/// A disabled control that still looks like the primary action is the shape of
/// a dark pattern even when nothing is being sold — the user taps, nothing
/// happens, and they learn to distrust the button.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.chatSend,
      child: SizedBox(
        width: Touch.minTarget,
        height: Touch.minTarget,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: Radii.fullAll,
            child: AnimatedContainer(
              duration: Motion.durationFor(context, Motion.feedback),
              curve: Motion.curveFor(context),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: enabled ? colors.signal : Colors.transparent,
                shape: BoxShape.circle,
                border: enabled ? null : Border.all(color: colors.line),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                // `bg` on amber is 11.22:1. CRITIQUE F7 is the reason this is
                // not `Colors.white`: white on `#FFB627` is 1.75:1, a button
                // impossible to miss and impossible to read.
                color: enabled ? colors.bg : colors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
