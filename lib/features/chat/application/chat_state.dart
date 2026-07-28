import 'package:ai_chatbot_app/core/result/app_failure.dart';
import 'package:ai_chatbot_app/features/chat/domain/chat_message.dart';
import 'package:ai_chatbot_app/features/chat/domain/chat_usage.dart';

/// What the chat screen renders.
///
/// One immutable object rather than eight fields on a `ChangeNotifier`. The old
/// `ChatProvider` was the latter, and the cost showed: `ref.watch` on a
/// `ChangeNotifier` rebuilds on every `notifyListeners()` regardless of which
/// field changed (CRITIQUE W1.2), so a single streamed token rebuilt the drawer,
/// the app bar, and the composer along with the transcript.
class ChatState {
  const ChatState({
    this.threadId,
    this.partnerId,
    this.messages = const [],
    this.usage,
    this.failure,
    this.isLoadingThread = false,
    this.isStreaming = false,
    this.truncated = false,
  });

  final String? threadId;

  /// Which partner the next message goes to. Null only before partners load.
  final String? partnerId;

  /// Oldest first. The last entry may be mid-stream.
  final List<ChatMessage> messages;

  /// What the server last said about the allowance. Null until the first reply
  /// of the session — the client does not guess it (F2).
  final ChatUsage? usage;

  /// The last failure, for the UI to render and then dismiss.
  ///
  /// Typed rather than a string, so the screen picks the copy from `l10n` and
  /// decides what to offer: a retry for offline, a paywall for quota (R8.3), a
  /// plain statement for a safety block (R10.5).
  final AppFailure? failure;

  final bool isLoadingThread;
  final bool isStreaming;

  /// The last reply stopped at the token ceiling rather than finishing.
  final bool truncated;

  bool get isEmpty => messages.isEmpty && !isLoadingThread;

  /// True only while waiting for the first token.
  ///
  /// The distinction matters for §16: this is when the waveform idles in place
  /// of a spinner. Once text is arriving, the text itself is the progress
  /// indicator and a second one would be noise.
  bool get isAwaitingFirstToken =>
      isStreaming &&
      (messages.isEmpty || messages.last.role == ChatRole.user);

  ChatState copyWith({
    String? threadId,
    String? partnerId,
    List<ChatMessage>? messages,
    ChatUsage? usage,
    bool? isLoadingThread,
    bool? isStreaming,
    bool? truncated,
    // Nullable fields need an explicit clear, because `null` in a copyWith
    // argument means "unchanged" everywhere else.
    bool clearFailure = false,
    AppFailure? failure,
    bool clearThread = false,
  }) => ChatState(
    threadId: clearThread ? null : (threadId ?? this.threadId),
    partnerId: partnerId ?? this.partnerId,
    messages: messages ?? this.messages,
    usage: usage ?? this.usage,
    failure: clearFailure ? null : (failure ?? this.failure),
    isLoadingThread: isLoadingThread ?? this.isLoadingThread,
    isStreaming: isStreaming ?? this.isStreaming,
    truncated: truncated ?? this.truncated,
  );
}
