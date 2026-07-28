/// One conversation.
///
/// Backed by the `threads` table (§9.5). A thread is shared between typed chat
/// and spoken sessions — §5.1: "Any typed conversation can be continued as a
/// spoken session with one tap, and vice versa: they share one thread." Nothing
/// here distinguishes the two, on purpose; Milestone 4 attaches sessions to the
/// same row rather than introducing a parallel concept.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.partnerId,
    required this.updatedAt,
  });

  factory ChatThread.fromRow(Map<String, dynamic> row) => ChatThread(
    id: row['id'] as String,
    title: row['title'] as String? ?? '',
    partnerId: row['partner_id'] as String?,
    updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
  );

  final String id;

  /// Derived server-side from the first message. Never a model call — see
  /// `deriveTitle` in the gateway contract for why.
  final String title;

  /// Null when the partner was deleted (`on delete set null`). The UI falls
  /// back rather than hiding the thread: losing a partner must not lose the
  /// transcript.
  final String? partnerId;

  final DateTime updatedAt;
}
