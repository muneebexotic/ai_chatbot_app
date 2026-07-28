import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/design/waveform/waveform.dart';
import 'package:speakwise/features/chat/application/chat_providers.dart';
import 'package:speakwise/features/chat/domain/chat_message.dart';
import 'package:speakwise/features/chat/presentation/widgets/ai_turn.dart';
import 'package:speakwise/features/chat/presentation/widgets/chat_failure_bar.dart';
import 'package:speakwise/features/chat/presentation/widgets/composer.dart';
import 'package:speakwise/features/chat/presentation/widgets/thread_drawer.dart';
import 'package:speakwise/features/chat/presentation/widgets/user_turn.dart';
import 'package:speakwise/features/partners/presentation/partner_picker.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// Typed chat, rebuilt on the design system (PRD §5.1, §7.4).
///
/// Replaces a 1190-line screen that owned its own Firestore calls, its own
/// paywall dialog, an image-generation empty state, and a `ChangeNotifier` that
/// rebuilt the whole tree on every streamed token.
///
/// ## The anti-generic check (R0.5.6)
///
/// "Would this screen be indistinguishable from any other AI app's version of
/// it? This applies hardest to the chat screen." The answers here are: the AI
/// speaks in a full-width serif column with a rule down its left edge and no
/// bubble; the user's turns are small and off to one side; the loading state is
/// the app's waveform idling, never a spinner; and the empty state names the
/// partner and offers to change them rather than listing prompt suggestions.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  String _lastSent = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Follows the reply as it grows, but only from the bottom.
  ///
  /// A chat that yanks you back down while you are reading earlier turns is one
  /// of the most common irritations in this category. The 120px threshold means
  /// scrolling up to re-read stops the follow, and returning to the bottom
  /// resumes it.
  void _followStream() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > 120) return;
    _scrollController.jumpTo(position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);

    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.messages.lastOrNull?.content !=
              next.messages.lastOrNull?.content) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _followStream());
      }
    });

    final partner = ref.watch(activePartnerProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      drawer: const ThreadDrawer(),
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // The partner's name IS the title. A screen titled "Chat" tells the
        // user something they can see; the name tells them who is answering,
        // and tapping it changes that.
        title: InkWell(
          borderRadius: Radii.controlAll,
          onTap: () async {
            final chosen = await showPartnerPicker(context, partner?.id);
            if (chosen != null) controller.selectPartner(chosen.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.xs,
              vertical: Space.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    partner?.name ?? l10n.appName,
                    style: AppTypography.title2.copyWith(color: colors.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Space.xxs),
                Icon(Icons.expand_more_rounded, size: 18, color: colors.muted),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.chatNewConversation,
            onPressed: controller.startNewThread,
            icon: Icon(Icons.add_rounded, color: colors.ink),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.isEmpty
                ? _EmptyState(partnerName: partner?.name)
                : _Transcript(
                    controller: _scrollController,
                    messages: state.messages,
                    truncated: state.truncated,
                    awaitingFirstToken: state.isAwaitingFirstToken,
                  ),
          ),
          if (state.usage?.shouldWarn ?? false)
            _RemainingNotice(remaining: state.usage!.remaining),
          if (state.failure != null)
            ChatFailureBar(
              failure: state.failure!,
              onDismiss: controller.dismissFailure,
              onRetry: () {
                controller.dismissFailure();
                if (_lastSent.isNotEmpty) controller.send(_lastSent);
              },
              onUpgrade: () {
                controller.dismissFailure();
                Navigator.of(context).pushNamed('/subscription');
              },
            ),
          Composer(
            enabled: !state.isStreaming && partner != null,
            onSend: (text) {
              _lastSent = text;
              controller.send(text);
            },
          ),
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.controller,
    required this.messages,
    required this.truncated,
    required this.awaitingFirstToken,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final bool truncated;
  final bool awaitingFirstToken;

  @override
  Widget build(BuildContext context) {
    // R11.3: "Long transcripts render in a lazy list, never a Column in a
    // ScrollView." The old screen used the latter.
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      itemCount: messages.length + (awaitingFirstToken ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return const _ThinkingIndicator();
        final message = messages[index];
        final isLast = index == messages.length - 1;
        return message.role == ChatRole.user
            ? UserTurn(message: message)
            : AiTurn(message: message, truncated: truncated && isLast);
      },
    );
  }
}

/// Waiting for the first token.
///
/// §16 and R7.5.2: "No spinner where the Waveform can idle instead." The old
/// screen used a three-dot typing indicator, which is the default every wrapper
/// ships. This is the same painter the session screen will use for live
/// amplitude — one visualization, everywhere (R7.5.3).
///
/// It disappears the moment the first word arrives, because from then on the
/// text is the progress indicator and a second one would be noise.
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
      // `Align` is load-bearing, not decoration.
      //
      // A ListView gives every item a TIGHT cross-axis constraint, and
      // `SizedBox` enforces its own constraints *within* the incoming ones —
      // so `SizedBox(width: 72)` inside a list item clamps 72 back up to the
      // full viewport width and does nothing. The first device pass showed a
      // row of fourteen fat amber pills stretched across the screen where a
      // small idle wave should have been.
      //
      // `Align` loosens the constraint first, which is what lets the SizedBox
      // mean what it says.
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 72,
          child: Waveform(
            mode: WaveformMode.idle,
            height: 24,
            barCount: 14,
            semanticLabel: l10n.chatThinking,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.partnerName});

  final String? partnerName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The empty state used to offer "Create Image" and "Generate
            // Images" chips — image generation, banned by §16, on the first
            // screen a signed-in user saw. It offers a sentence now.
            Text(
              partnerName == null
                  ? l10n.chatEmptyTitle
                  : l10n.chatEmptyTitleWithPartner(partnerName!),
              style: AppTypography.display3.copyWith(color: colors.ink),
            ),
            const SizedBox(height: Space.sm),
            Text(
              l10n.chatEmptyBody,
              style: AppTypography.body2.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The remaining-message count, shown only near the end (§8, §16).
///
/// A counter visible from the first message turns every reply into a
/// transaction and is manufactured scarcity by another name. This appears at
/// five left and says what happens next, including that Drill Mode — the
/// unlimited free surface (DECISIONS D2) — is unaffected.
class _RemainingNotice extends StatelessWidget {
  const _RemainingNotice({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Text(
        l10n.chatMessagesRemaining(remaining),
        style: AppTypography.micro.copyWith(color: colors.muted),
      ),
    );
  }
}
