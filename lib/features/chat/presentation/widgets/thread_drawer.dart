import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/tokens/app_metrics.dart';
import 'package:ai_chatbot_app/design/tokens/app_typography.dart';
import 'package:ai_chatbot_app/design/waveform/waveform.dart';
import 'package:ai_chatbot_app/features/chat/application/chat_providers.dart';
import 'package:ai_chatbot_app/features/chat/domain/chat_thread.dart';
import 'package:ai_chatbot_app/features/memory/presentation/memory_screen.dart';
import 'package:ai_chatbot_app/l10n/app_localizations.dart';

/// Conversation history.
///
/// Replaces `conversation_drawer.dart`, which was 933 lines, read Firestore
/// directly, and drew its "New Chat" action as a blue-to-cyan gradient —
/// banned by §7.1.2 outside the waveform, in a hue the §7 anti-brief names
/// explicitly (CRITIQUE F5).
class ThreadDrawer extends ConsumerWidget {
  const ThreadDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final threads = ref.watch(threadsProvider);
    final currentId = ref.watch(chatControllerProvider).threadId;

    return Drawer(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radii.sheet),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
              child: Text(
                l10n.threadsTitle,
                style: AppTypography.title2.copyWith(color: colors.ink),
              ),
            ),
            Expanded(
              child: threads.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Space.xl),
                  child: Waveform(mode: WaveformMode.idle, height: 40),
                ),
                error: (_, _) => _Message(text: l10n.threadsUnavailable),
                data: (list) => list.isEmpty
                    ? _Message(text: l10n.threadsEmpty)
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: list.length,
                        itemBuilder: (context, index) => _ThreadRow(
                          thread: list[index],
                          selected: list[index].id == currentId,
                        ),
                      ),
              ),
            ),
            Divider(height: 1, color: colors.line),
            // Memory is reachable from here rather than buried in settings.
            // R5.2.2 calls showing it "a trust feature and a differentiator",
            // and a differentiator three taps deep differentiates nothing.
            ListTile(
              leading: Icon(Icons.bookmark_border_rounded, color: colors.muted),
              title: Text(
                l10n.memoryTitle,
                style: AppTypography.body2.copyWith(color: colors.ink),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MemoryScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: colors.muted),
              title: Text(
                l10n.settingsTitle,
                style: AppTypography.body2.copyWith(color: colors.ink),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow({required this.thread, required this.selected});

  final ChatThread thread;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Dismissible(
      key: ValueKey(thread.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.md),
        color: colors.surfaceRaised,
        child: Text(
          l10n.threadDelete,
          style: AppTypography.label.copyWith(color: colors.ink),
        ),
      ),
      confirmDismiss: (_) async {
        // A transcript is not trivially recreatable, so deletion asks. §16 bans
        // hard-to-cancel flows, not confirmations of destructive acts — the
        // dark pattern would be making this hard to undo, not asking once.
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: colors.surface,
            title: Text(
              l10n.threadDeleteTitle,
              style: AppTypography.title2.copyWith(color: colors.ink),
            ),
            content: Text(
              l10n.threadDeleteBody,
              style: AppTypography.body2.copyWith(color: colors.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionKeep),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  l10n.threadDelete,
                  style: TextStyle(color: colors.live),
                ),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) async {
        await ref.read(chatRepositoryProvider).deleteThread(thread.id);
        if (selected) ref.read(chatControllerProvider.notifier).startNewThread();
        ref.invalidate(threadsProvider);
      },
      child: ListTile(
        selected: selected,
        selectedTileColor: colors.surfaceRaised,
        title: Text(
          thread.title.isEmpty ? l10n.threadUntitled : thread.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body2.copyWith(color: colors.ink),
        ),
        subtitle: Text(
          _relativeDate(context, thread.updatedAt),
          // Geist Mono: §7.2 puts dates on the data face.
          style: AppTypography.dataSmall.copyWith(color: colors.muted),
        ),
        onTap: () {
          Navigator.of(context).pop();
          ref.read(chatControllerProvider.notifier).openThread(thread.id);
        },
      ),
    );
  }

  String _relativeDate(BuildContext context, DateTime when) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(when.year, when.month, when.day))
        .inDays;
    if (days == 0) return l10n.dateToday;
    if (days == 1) return l10n.dateYesterday;
    if (days < 7) return l10n.dateDaysAgo(days);
    return '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Text(
        text,
        style: AppTypography.body2.copyWith(color: colors.muted),
      ),
    );
  }
}
