import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/features/chat/domain/chat_message.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// The AI's turn — PRD R7.4.1.
///
/// "The AI's turns are NOT bubbles. They are typeset paragraphs in Newsreader,
/// full width, with a thin `signal` rule on the left. The user's turns are
/// compact right-aligned `surfaceRaised` bubbles in General Sans. **This
/// asymmetry is the identity: the AI is publishing, the user is speaking.**"
///
/// This is the single widget that most decides whether the app passes R0.5.6's
/// anti-generic check. Two bubbles facing each other is what every wrapper
/// ships; a serif column with a rule down its edge is a page from a printed
/// interview, and it is recognisable in a screenshot from across a room.
///
/// ## What is deliberately absent
///
/// No avatar, no name label, no timestamp, no bubble, no shadow, no background
/// tint. The rule is the only chrome, and it is 2dp wide. Everything a
/// conventional chat UI puts around a message is furniture that competes with
/// the words, and the words here are meant to read like print.
///
/// The old `app_message_bubble.dart` was 603 lines and drew a gradient-filled
/// bubble with an avatar, a shadow tinted with `primaryColor`, and three
/// markdown packages behind it. It is deleted in this milestone (DECISIONS D4).
class AiTurn extends StatelessWidget {
  const AiTurn({super.key, required this.message, this.truncated = false});

  final ChatMessage message;

  /// The reply stopped at the model's token ceiling. Said plainly rather than
  /// hidden — a paragraph that stops mid-thought reads as a bug otherwise.
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final text = message.visibleContent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
      // The signal rule is a LEFT BORDER on the text, not a sibling bar.
      //
      // The first version was a `Row(crossAxisAlignment: stretch)` with a 2dp
      // Container beside the text, and the comment above it claimed this
      // avoided `IntrinsicHeight`. It did — by not rendering. `stretch` gives
      // children a tight cross-axis constraint taken from the Row's own height,
      // and a Row inside a vertical ListView has no bounded height to take it
      // from, so every AI turn collapsed to zero and the reply was invisible.
      //
      // The server had stored it correctly the whole time. Found by sending a
      // message on a device and seeing nothing come back — no error, no text,
      // exactly the silent failure that is hardest to diagnose from logs.
      //
      // A border sizes itself to the content for free, costs no extra layout
      // pass, and keeps R11.2's 60fps budget intact.
      child: Container(
        padding: const EdgeInsets.only(left: Space.sm),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: colors.signal, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selectable so a user can quote what the partner said. §5.1 asks
            // for a copy button on code blocks; the whole turn being selectable
            // is the cheaper, more general answer for prose.
            SelectionArea(
              child: GptMarkdown(
                text,
                style: AppTypography.transcriptAi.copyWith(color: colors.ink),
                codeBuilder: (context, name, code, closed) =>
                    _CodeBlock(code: code, language: name),
                highlightBuilder: (context, inline, style) => _InlineCode(
                  text: inline,
                  style: style,
                ),
              ),
            ),
            if (truncated && !message.isStreaming)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  l10n.chatReplyTruncated,
                  style: AppTypography.micro.copyWith(color: colors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A fenced code block (§5.1).
///
/// Horizontally scrollable, which is the fix for CRITIQUE F3: the old bubble
/// clipped `session 04 · 6m 12s · fillers 7/min` mid-word at the right edge in
/// both modes with no way to see the rest. That was left standing in Milestone
/// 1 explicitly because §7.4 rewrites this surface — this is the rewrite.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: Space.xs),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: Radii.controlAll,
        // §7.3: elevation is a 1dp line border, never a shadow on a flat card.
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, 0, 0),
                child: Text(
                  language.isEmpty ? l10n.chatCodeBlock : language,
                  style: AppTypography.micro.copyWith(color: colors.muted),
                ),
              ),
              const Spacer(),
              _CopyButton(text: code),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.xxs, Space.sm, Space.sm),
            child: Text(
              code,
              style: AppTypography.dataSmall.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineCode extends StatelessWidget {
  const _InlineCode({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        text,
        // `ink` explicitly. Inline code inherited a colour that was invisible
        // in dark mode before F1 was fixed, and inheriting again would make
        // this dependent on whatever the surrounding style happens to be.
        style: style.copyWith(
          fontFamily: AppTypography.monoFamily,
          color: colors.ink,
          fontSize: (style.fontSize ?? 15) * 0.92,
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});
  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return TextButton(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (!mounted) return;
        // Confirmation in place, not a snackbar over the conversation. The
        // feedback belongs where the action was.
        setState(() => _copied = true);
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(Touch.minTarget, Touch.minTarget),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      ),
      child: Text(
        _copied ? l10n.chatCopied : l10n.chatCopy,
        style: AppTypography.micro.copyWith(
          color: _copied ? colors.good : colors.muted,
        ),
      ),
    );
  }
}
