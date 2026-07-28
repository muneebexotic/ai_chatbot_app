import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/features/chat/application/chat_providers.dart';
import 'package:speakwise/features/chat/application/chat_state.dart';
import 'package:speakwise/features/chat/data/gateway_client.dart';
import 'package:speakwise/features/chat/domain/chat_message.dart';
import 'package:speakwise/features/chat/domain/gateway_event.dart';
import 'package:speakwise/features/memory/application/memory_providers.dart';
import 'package:speakwise/features/partners/application/partner_providers.dart';

/// Drives one conversation.
///
/// A real Riverpod `Notifier`, not a `ChangeNotifier` behind a shim. DECISIONS
/// D5 time-boxed the shims to "until the feature is rebuilt, at which point it
/// is a rewrite of code already being rewritten" and named chat as Milestone 3.
/// This is that rewrite.
///
/// ## What moved to the server
///
/// The old `ChatProvider` decided whether the user could send (`_canSendMessage`
/// reading a local counter), incremented usage locally, called the model
/// directly with a key from the APK, and defaulted to *allowing* the message
/// when the quota check threw. Every one of those is now the gateway's, and the
/// notifier's job is reduced to what a UI layer should do: hold the transcript,
/// reflect what the server said, and surface a typed failure.
class ChatController extends Notifier<ChatState> {
  StreamSubscription<GatewayEvent>? _subscription;

  @override
  ChatState build() {
    // Cancelling here rather than in a `dispose` override: a rebuild of the
    // provider must not leave a stream writing into a state object nobody is
    // watching any more.
    ref.onDispose(() => _subscription?.cancel());

    // NOTHING IS WATCHED HERE, deliberately.
    //
    // The first version read `ref.watch(partnersProvider)` to seed a default
    // partner. `Notifier.build` re-runs whenever a watched provider changes and
    // **discards the state it returned last time** — so anything that
    // invalidated the partner list mid-conversation would silently wipe the
    // transcript. It reloads on every auth event, which includes a routine
    // token refresh.
    //
    // The default partner is derived instead, in [activePartnerProvider],
    // where recomputing costs nothing.
    return const ChatState();
  }

  /// Which partner the next message actually goes to.
  ///
  /// The explicit choice if there is one, otherwise the first of the sorted
  /// list — Free Talk. Null only while partners are still loading.
  String? _resolvePartnerId() =>
      state.partnerId ??
      ref.read(partnersProvider).valueOrNull?.firstOrNull?.id;

  void selectPartner(String partnerId) {
    state = state.copyWith(partnerId: partnerId);
  }

  void dismissFailure() {
    state = state.copyWith(clearFailure: true);
  }

  /// Abandons the current thread. The next message starts a new one.
  void startNewThread() {
    _subscription?.cancel();
    state = ChatState(partnerId: state.partnerId, usage: state.usage);
  }

  /// Loads an existing conversation from history.
  Future<void> openThread(String threadId) async {
    _subscription?.cancel();
    state = ChatState(
      threadId: threadId,
      partnerId: state.partnerId,
      usage: state.usage,
      isLoadingThread: true,
    );

    final result = await ref.read(chatRepositoryProvider).messages(threadId);
    switch (result) {
      case Ok(:final value):
        state = state.copyWith(messages: value, isLoadingThread: false);
      case Err(:final failure):
        state = state.copyWith(isLoadingThread: false, failure: failure);
    }
  }

  /// Sends [text] and streams the reply.
  ///
  /// The user's turn is appended optimistically. That is safe here in a way it
  /// would not be for the assistant's turn: the gateway persists the user
  /// message before it calls the model, so the only case where the optimistic
  /// row is wrong is a request that never reached the server — and in that case
  /// R11.5 requires the words to stay on screen anyway rather than vanish.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    final partnerId = _resolvePartnerId();
    if (trimmed.isEmpty || state.isStreaming || partnerId == null) return;

    final token = ref.read(accessTokenProvider);
    if (token == null) {
      state = state.copyWith(failure: const UnauthorizedFailure());
      return;
    }

    // A local id, replaced by the server's on the meta frame. Not a uuid on
    // purpose — nothing should be able to mistake it for one and send it back.
    final pendingId = 'local-${DateTime.now().microsecondsSinceEpoch}';

    state = state.copyWith(
      clearFailure: true,
      truncated: false,
      isStreaming: true,
      messages: [
        ...state.messages,
        ChatMessage(
          id: pendingId,
          role: ChatRole.user,
          content: trimmed,
          createdAt: DateTime.now(),
        ),
      ],
    );

    final completer = Completer<void>();
    var reply = '';
    var replyId = 'local-reply-$pendingId';

    _subscription?.cancel();
    _subscription = ref
        .read(gatewayClientProvider)
        .send(
          accessToken: token,
          partnerId: partnerId,
          text: trimmed,
          threadId: state.threadId,
        )
        .listen(
          (event) {
            switch (event) {
              case GatewayMeta():
                state = state.copyWith(
                  threadId: event.threadId,
                  usage: event.usage,
                  messages: [
                    for (final m in state.messages)
                      if (m.id == pendingId)
                        m.copyWith(id: event.userMessageId)
                      else
                        m,
                  ],
                );

              case GatewayDelta():
                reply += event.text;
                final existing = state.messages.any((m) => m.id == replyId);
                state = state.copyWith(
                  messages: existing
                      ? [
                          for (final m in state.messages)
                            if (m.id == replyId)
                              m.copyWith(content: reply)
                            else
                              m,
                        ]
                      : [
                          ...state.messages,
                          ChatMessage(
                            id: replyId,
                            role: ChatRole.assistant,
                            content: reply,
                            createdAt: DateTime.now(),
                            isStreaming: true,
                          ),
                        ],
                );

              case GatewayDone():
                final serverId = event.messageId ?? replyId;
                state = state.copyWith(
                  truncated: event.truncated,
                  messages: [
                    for (final m in state.messages)
                      if (m.id == replyId)
                        m.copyWith(id: serverId, isStreaming: false)
                      else
                        m,
                  ],
                );
                replyId = serverId;
            }
          },
          onError: (Object error, StackTrace stack) {
            state = state.copyWith(
              isStreaming: false,
              failure: error is GatewayFailure
                  ? error.failure
                  : UnknownFailure(cause: error, stackTrace: stack),
              // Whatever arrived before the failure stays, and stops being
              // marked as streaming so it renders whole rather than one word
              // short forever.
              messages: [
                for (final m in state.messages)
                  if (m.isStreaming) m.copyWith(isStreaming: false) else m,
              ],
            );
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            state = state.copyWith(isStreaming: false);
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    await completer.future;

    // R5.2.1 extraction, after the reply and off the critical path. Awaiting it
    // would put a second model call between the user and their next turn for
    // the benefit of a feature that is allowed to be late or to fail.
    final threadId = state.threadId;
    if (threadId != null && state.failure == null && state.messages.length >= 4) {
      unawaited(
        ref
            .read(memoryRepositoryProvider)
            .extractFrom(threadId)
            .then((_) => ref.invalidate(memoriesProvider))
            .catchError((Object e) => Log.w('memory: extraction threw', error: e)),
      );
    }

    // The thread list orders by activity and has just changed.
    ref.invalidate(threadsProvider);
  }
}
