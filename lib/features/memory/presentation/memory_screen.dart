import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_chatbot_app/design/tokens/app_colors.dart';
import 'package:ai_chatbot_app/design/tokens/app_metrics.dart';
import 'package:ai_chatbot_app/design/tokens/app_typography.dart';
import 'package:ai_chatbot_app/design/waveform/waveform.dart';
import 'package:ai_chatbot_app/features/memory/application/memory_providers.dart';
import 'package:ai_chatbot_app/features/memory/domain/memory_item.dart';
import 'package:ai_chatbot_app/l10n/app_localizations.dart';

/// What the app remembers, and how to make it forget (PRD R5.2.2).
///
/// "Memory is **visible and editable**: a Memory screen lists every stored item
/// with its date, each deletable, with a 'forget everything' action. **Most
/// competitors hide this. Showing it is a trust feature and a
/// differentiator.**"
///
/// The screen is written to be read by someone who is slightly uneasy about
/// what an app has stored, because that is who opens it. So it leads with the
/// two facts that answer the worry — what is kept, and what is never kept —
/// before it lists anything. The never-kept list is R5.2.4's categories stated
/// in plain words, which is a claim the code actually backs: there is a
/// deny-instruction in the extraction prompt and a keyword filter over every
/// candidate, and neither the app nor the user can write to this table.
class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final memories = ref.watch(memoriesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.memoryTitle,
          style: AppTypography.title2.copyWith(color: colors.ink),
        ),
        actions: [
          if (memories.valueOrNull?.isNotEmpty ?? false)
            TextButton(
              onPressed: () => _confirmForgetAll(context, ref),
              child: Text(
                l10n.memoryForgetAll,
                style: AppTypography.label.copyWith(color: colors.signal),
              ),
            ),
        ],
      ),
      body: memories.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Space.xl),
          child: Waveform(mode: WaveformMode.idle, height: 48),
        ),
        error: (_, _) => _Note(text: l10n.memoryUnavailable),
        data: (items) => ListView(
          padding: const EdgeInsets.only(bottom: Space.xl),
          children: [
            const _Preamble(),
            if (items.isEmpty)
              _Note(text: l10n.memoryEmpty)
            else
              for (final item in items)
                _MemoryRow(
                  item: item,
                  onForget: () async {
                    await ref.read(memoryRepositoryProvider).forget(item.id);
                    ref.invalidate(memoriesProvider);
                  },
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmForgetAll(BuildContext context, WidgetRef ref) async {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          l10n.memoryForgetAllTitle,
          style: AppTypography.title2.copyWith(color: colors.ink),
        ),
        content: Text(
          l10n.memoryForgetAllBody,
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
              l10n.memoryForgetAll,
              style: TextStyle(color: colors.live),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(memoryRepositoryProvider).forgetAll();
    ref.invalidate(memoriesProvider);
  }
}

class _Preamble extends StatelessWidget {
  const _Preamble();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.memoryExplainer,
            style: AppTypography.body2.copyWith(color: colors.muted),
          ),
          const SizedBox(height: Space.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: Radii.cardAll,
              border: Border.all(color: colors.line),
            ),
            child: Text(
              // R5.2.4's categories, in the words a person would use. Stated
              // as a promise the implementation keeps rather than as legal
              // boilerplate nobody reads.
              l10n.memoryNeverStored,
              style: AppTypography.label.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.item, required this.onForget});

  final MemoryItem item;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.xxs, Space.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.cardAll,
        border: Border.all(color: colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content,
                  style: AppTypography.body2.copyWith(color: colors.ink),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  // R5.2.2 requires the date. Geist Mono, per §7.2.
                  '${item.createdAt.year}-'
                  '${item.createdAt.month.toString().padLeft(2, '0')}-'
                  '${item.createdAt.day.toString().padLeft(2, '0')}',
                  style: AppTypography.dataSmall.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onForget,
            tooltip: l10n.memoryForgetOne,
            iconSize: 18,
            icon: Icon(Icons.close_rounded, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
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
