/// Who said it.
///
/// Mirrors the `message_role` enum in Postgres (§9.5). Two values, because a
/// system prompt is never a message: it is server state the client does not
/// hold and cannot see (R9.3.2).
enum ChatRole { user, assistant }

/// One turn in a thread.
///
/// Immutable, per §9.1. The streaming case is handled by *replacing* the last
/// message with a longer copy rather than mutating it, which is what lets the
/// UI diff cheaply and what stops a half-written message from being observed
/// mid-append.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
  });

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
    id: row['id'] as String,
    role: (row['role'] as String) == 'user' ? ChatRole.user : ChatRole.assistant,
    content: row['content'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  /// True while the gateway is still sending this message.
  ///
  /// Drives the reveal in [visibleContent] and nothing else. It is deliberately
  /// not a separate "typing" object in the state: a placeholder that is not a
  /// message has to be special-cased by the list, the scroll controller, and
  /// every accessibility path, and one of those always gets forgotten.
  final bool isStreaming;

  /// The text to draw right now.
  ///
  /// R7.4.2: "Streaming responses reveal by word, not by character, with no
  /// cursor artefact and no layout jump."
  ///
  /// The gateway forwards model tokens, which are sub-word — "inter", "view",
  /// "ing". Rendering those directly is the character-by-character typewriter
  /// the requirement rules out, and it is genuinely worse to read: a word that
  /// materialises in three pieces makes the eye re-fixate three times.
  ///
  /// So while streaming, everything after the last completed word is withheld.
  /// The result advances one whole word at a time even though the transport is
  /// finer-grained than that. Once the stream ends the full text shows,
  /// including a trailing partial word if the model was cut off mid-word.
  String get visibleContent {
    if (!isStreaming) return content;
    final lastBreak = content.lastIndexOf(RegExp(r'[\s\n]'));
    if (lastBreak <= 0) return '';
    return content.substring(0, lastBreak);
  }

  ChatMessage copyWith({String? id, String? content, bool? isStreaming}) =>
      ChatMessage(
        id: id ?? this.id,
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          id == other.id &&
          content == other.content &&
          isStreaming == other.isStreaming);

  @override
  int get hashCode => Object.hash(id, content, isStreaming);
}
