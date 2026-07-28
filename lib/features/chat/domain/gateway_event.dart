import 'package:ai_chatbot_app/features/chat/domain/chat_usage.dart';

/// What arrives while a reply is being written.
///
/// Sealed, for the same reason `AppFailure` is (F4): a `switch` over it is
/// exhaustive, so adding a new event kind becomes a compile error at every site
/// that must handle it rather than something that falls quietly into a default
/// branch.
///
/// These are the gateway's own events, not the model provider's. R9.3.3
/// requires routing to be provider-agnostic so a different provider is a config
/// change — which would not be true if Groq's SSE shape reached this file.
sealed class GatewayEvent {
  const GatewayEvent();
}

/// Sent once, before any text.
///
/// Carries the thread id — which the client does not know when it starts a new
/// conversation, because the gateway creates the row — and the usage the server
/// recorded for this call.
final class GatewayMeta extends GatewayEvent {
  const GatewayMeta({
    required this.threadId,
    required this.isNewThread,
    required this.userMessageId,
    required this.usage,
  });

  final String threadId;
  final bool isNewThread;
  final String userMessageId;
  final ChatUsage usage;
}

/// A fragment of the reply. Sub-word: see `ChatMessage.visibleContent` for why
/// that does not reach the screen as-is.
final class GatewayDelta extends GatewayEvent {
  const GatewayDelta(this.text);
  final String text;
}

/// The reply finished.
final class GatewayDone extends GatewayEvent {
  const GatewayDone({required this.messageId, required this.truncated});

  /// Null if the assistant message could not be persisted. The text is still on
  /// screen; it just will not survive a reload, and the UI should not pretend
  /// otherwise.
  final String? messageId;

  /// The model hit `max_tokens` rather than choosing to stop. Surfaced rather
  /// than hidden — a reply that ends mid-thought looks like a bug, and saying
  /// so is cheaper than letting the reader wonder.
  final bool truncated;
}
