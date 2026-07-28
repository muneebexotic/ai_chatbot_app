import 'package:flutter/material.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/tokens/app_metrics.dart';
import 'package:ai_chatbot_app/design/tokens/app_typography.dart';
import 'package:ai_chatbot_app/features/chat/domain/chat_message.dart';

/// The user's turn — PRD R7.4.1.
///
/// "compact right-aligned `surfaceRaised` bubbles in General Sans."
///
/// Compact is the operative word and the reason for the 78% width cap. The
/// asymmetry only reads as *the AI is publishing, the user is speaking* if the
/// user's side stays visibly smaller than the full-bleed serif column beside
/// it. A user bubble that stretches to the same width is two chat bubbles
/// again, in different fonts.
///
/// No gradient, no shadow. The old bubble had
/// `LinearGradient([primaryColor, colorScheme.secondary])` with a
/// `primaryColor.withValues(alpha: 0.2)` glow — which §7.1.2 bans outside the
/// waveform, and which rendered the user's own words at 1.09:1 in dark mode
/// until CRITIQUE F1 was fixed. §7.3 allows one soft shadow in the whole app,
/// reserved for sheets and the floating session control. This is neither.
class UserTurn extends StatelessWidget {
  const UserTurn({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      child: Align(
        alignment: Alignment.centerRight,
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
              borderRadius: const BorderRadius.only(
                topLeft: Radii.card,
                topRight: Radii.card,
                bottomLeft: Radii.card,
                // Square on the corner nearest the edge it came from. One
                // asymmetric corner is enough to give the bubble a direction
                // without a tail, which is the cheapest available way to say
                // "this side is you".
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(color: colors.line),
            ),
            child: SelectionArea(
              child: Text(
                message.content,
                style: AppTypography.transcriptUser.copyWith(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
