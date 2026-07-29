import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/features/partners/application/partner_providers.dart';
import 'package:speakwise/features/partners/domain/partner.dart';
import 'package:speakwise/features/partners/presentation/partner_picker.dart';
import 'package:speakwise/features/session/application/session_providers.dart';
import 'package:speakwise/features/session/domain/session_record.dart';
import 'package:speakwise/features/session/presentation/session_brief_screen.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// R4.1.1: "Home surfaces one primary action: **Start speaking**. Under it, a
/// horizontal rail of partners."
///
/// One primary action, and it is a verb. §3 puts the reason plainly: "Build it
/// as the centre of the product, not as a mode hidden behind a microphone
/// icon."
class SessionHomeScreen extends ConsumerWidget {
  const SessionHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final partners = ref.watch(partnersProvider);
    final history = ref.watch(sessionHistoryProvider);
    final unfinished = ref.watch(unfinishedSessionsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.appName,
          style: AppTypography.title2.copyWith(color: colors.ink),
        ),
        actions: [
          // §5.1: typed chat "stays, as the quiet half of the product". One
          // tap from here rather than the landing screen — §4 makes Sessions
          // the centre, and Milestone 3 had this the other way round.
          IconButton(
            tooltip: l10n.chatNewConversation,
            onPressed: () => Navigator.of(context).pushNamed('/chat'),
            icon: Icon(Icons.forum_outlined, color: colors.ink),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: Icon(Icons.tune_rounded, color: colors.ink),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          children: [
            // R4.2.6: a force-killed session still has its transcript, and the
            // user should be told rather than left to assume it vanished.
            ...unfinished.maybeWhen(
              data: (sessions) => sessions
                  .take(1)
                  .map((s) => _RecoveredNotice(session: s))
                  .toList(),
              orElse: () => const [],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                Space.lg,
              ),
              child: Text(
                l10n.sessionHomeTitle,
                style: AppTypography.display3.copyWith(color: colors.ink),
              ),
            ),

            // The partner rail (R4.1.1).
            SizedBox(
              // Tall enough for a two-line name plus a two-line description at
              // 200% text scale's smaller cousins. The rail is horizontal, so
              // height is the one axis nothing else can negotiate.
              height: 200,
              child: partners.when(
                data: (list) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                  itemBuilder: (context, index) => _PartnerCard(
                    partner: list[index],
                    onTap: () => _openBrief(context, list[index]),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: Space.xl),

            // R4.1.1's single primary action. Starts with the first partner —
            // Free Talk — so it is genuinely one tap for somebody who does not
            // want to choose.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: partners.valueOrNull?.isNotEmpty ?? false
                      ? () => _openBrief(context, partners.value!.first)
                      : null,
                  child: Text(l10n.sessionStartSpeaking),
                ),
              ),
            ),

            const SizedBox(height: Space.xl),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Text(
                l10n.sessionHistoryTitle,
                style: AppTypography.label.copyWith(
                  color: colors.muted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: Space.sm),

            history.when(
              data: (sessions) => sessions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.md,
                        vertical: Space.sm,
                      ),
                      child: Text(
                        // §7.6's own worked example of an empty state.
                        l10n.sessionHomeEmptyHistory,
                        style: AppTypography.body2.copyWith(color: colors.muted),
                      ),
                    )
                  : Column(
                      children: [
                        for (final session in sessions)
                          _HistoryRow(session: session),
                      ],
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBrief(BuildContext context, Partner partner) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionBriefScreen(partner: partner),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.onTap});

  final Partner partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      borderRadius: Radii.cardAll,
      onTap: onTap,
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: Radii.cardAll,
          border: Border.all(color: colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The same painter as everything else (R7.5.3).
            PartnerMark(partner: partner, width: 56),
            const Spacer(),
            Text(
              partner.name,
              style: AppTypography.title2.copyWith(color: colors.ink),
              // Two lines, not one. At 168dp a single line ellipsised
              // "Conversation Partner" to "Conversation ..." and "Interviewer"
              // to "Inte..." — the partner's name is the most important thing
              // on the card and the rail showed three cards where none of them
              // could be read. Found on device; the widget test asserted the
              // card existed, not that its label survived.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Space.xxs),
            Text(
              partner.description,
              style: AppTypography.micro.copyWith(color: colors.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// R4.2.6's recovered session, offered rather than hidden.
class _RecoveredNotice extends StatelessWidget {
  const _RecoveredNotice({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // Derived from the turns that survived, not from a duration nobody wrote.
    final minutes = session.duration?.inMinutes ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.cardAll,
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sessionRecoveredTitle,
            style: AppTypography.body2.copyWith(color: colors.ink),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            l10n.sessionRecoveredBody(minutes),
            style: AppTypography.micro.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final minutes = session.duration?.inMinutes ?? 0;
    final seconds = (session.duration?.inSeconds ?? 0) % 60;

    return Container(
      margin: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.cardAll,
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              session.partnerName,
              style: AppTypography.body2.copyWith(color: colors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // §7.2: mono for durations.
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: AppTypography.dataSmall.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}
