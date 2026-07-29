import 'package:flutter/material.dart';

import 'package:speakwise/core/speech_metrics/transcript.dart';
import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/features/session/domain/session_state.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// The live transcript (PRD R4.2.5, §7.4).
///
/// R4.2.5: "The transcript is live, labelled by speaker, and tappable: tapping
/// any AI line replays that line's audio; tapping any user line shows what the
/// recognizer heard."
///
/// Replay of an AI line is the waveform-as-scrubber use in R7.5.2 and belongs
/// with the report (Milestone 5), where a finished session has audio positions
/// to scrub. Here the tap on a user line is the half that matters live: a
/// recogniser that mishears is the category's most common complaint
/// (RESEARCH.md §1.3), and seeing the mishearing is the difference between "the
/// app is broken" and "it heard me wrong".
///
/// ## Layout
///
/// §7.4's asymmetry, applied to speech: the partner is a full-width Newsreader
/// paragraph with a `signal` rule down its left edge, the user is a compact
/// right-aligned `surfaceRaised` bubble in General Sans. "The AI is publishing,
/// the user is speaking."
///
/// R11.3 requires a lazy list, never a `Column` in a `ScrollView` — a
/// twenty-minute session is a long transcript.
class SessionTranscript extends StatefulWidget {
  const SessionTranscript({
    super.key,
    required this.turns,
    required this.partialText,
  });

  final List<SessionTurn> turns;

  /// The in-progress recognition. Rendered as a turn that has not settled.
  final String partialText;

  @override
  State<SessionTranscript> createState() => _SessionTranscriptState();
}

class _SessionTranscriptState extends State<SessionTranscript> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant SessionTranscript old) {
    super.didUpdateWidget(old);
    if (old.turns.length != widget.turns.length ||
        old.partialText != widget.partialText) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  /// Follows the conversation, but only from the bottom.
  ///
  /// Same rule as the chat surface: a transcript that yanks you back down while
  /// you are re-reading an earlier answer is one of the most irritating things
  /// in this category, and during a spoken session the user is often reading
  /// the last thing they said while the partner talks over it.
  void _follow() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > 120) return;
    _scroll.jumpTo(position.maxScrollExtent);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPartial = widget.partialText.trim().isNotEmpty;

    return Semantics(
      label: l10n.sessionTranscriptSemantics(widget.turns.length),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        itemCount: widget.turns.length + (hasPartial ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.turns.length) {
            return _PartialLine(text: widget.partialText);
          }
          final turn = widget.turns[index];
          return turn.speaker == Speaker.user
              ? _UserLine(turn: turn)
              : _PartnerLine(turn: turn);
        },
      ),
    );
  }
}

/// The partner's turn: typeset, not a bubble (§7.4.1).
class _PartnerLine extends StatelessWidget {
  const _PartnerLine({required this.turn});

  final SessionTurn turn;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: Space.sm),
        // A left BORDER rather than a Row with a rule beside it. Milestone 3
        // learned this the expensive way: `Row(crossAxisAlignment: stretch)`
        // inside a ListView renders at zero height, silently, with analyze
        // clean. A border sizes itself to the content and costs no extra
        // layout pass.
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.signal, width: 2)),
        ),
        child: Text(
          turn.text,
          // The typographic signature (§7.2): the partner's words as a serif
          // transcript, an interview in print rather than a chat bubble.
          style: AppTypography.transcriptAi.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}

/// The user's turn: a compact right-aligned bubble (§7.4.1).
class _UserLine extends StatefulWidget {
  const _UserLine({required this.turn});

  final SessionTurn turn;

  @override
  State<_UserLine> createState() => _UserLineState();
}

class _UserLineState extends State<_UserLine> {
  bool _showHeard = false;

  /// Below this, the recogniser was guessing. Surfaced rather than hidden:
  /// R4.2.5 exists because a strange transcript should read as a mishearing,
  /// not as the user's own words.
  static const _lowConfidence = 0.6;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final turn = widget.turn;
    final uncertain = turn.confidence > 0 && turn.confidence < _lowConfidence;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // R4.2.5: tapping a user line shows what the recogniser heard.
          Semantics(
            button: true,
            label: '${l10n.sessionYou}. ${turn.text}',
            child: InkWell(
              borderRadius: Radii.cardAll,
              onTap: () => setState(() => _showHeard = !_showHeard),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm,
                    vertical: Space.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: Radii.cardAll,
                    border: Border.all(color: colors.line),
                  ),
                  child: Text(
                    turn.text,
                    style: AppTypography.transcriptUser.copyWith(color: colors.ink),
                  ),
                ),
              ),
            ),
          ),
          if (_showHeard && uncertain)
            Padding(
              padding: const EdgeInsets.only(top: Space.xxs),
              child: Text(
                l10n.sessionHeardPoorly,
                style: AppTypography.micro.copyWith(color: colors.muted),
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

/// What the recogniser is hearing right now — not yet a turn.
///
/// Muted rather than full-strength ink, because it is going to change. A
/// partial rendered as settled text makes the transcript look like it is
/// rewriting itself.
class _PartialLine extends StatelessWidget {
  const _PartialLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Text(
            text,
            style: AppTypography.transcriptUser.copyWith(color: colors.muted),
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  }
}
