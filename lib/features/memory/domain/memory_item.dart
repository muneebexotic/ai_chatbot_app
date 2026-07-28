/// One durable fact the app has stored about the user (PRD §5.2).
///
/// Short by construction: the extraction function rejects anything under 8 or
/// over 160 characters, because a model ignoring "one short sentence" usually
/// does so by returning a slab of transcript, and a slab is far more likely to
/// carry something R5.2.4 forbids.
class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.content,
    required this.createdAt,
    this.sourceThreadTitle,
  });

  factory MemoryItem.fromRow(Map<String, dynamic> row) => MemoryItem(
    id: row['id'] as String,
    content: row['content'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );

  final String id;
  final String content;

  /// R5.2.2 requires the date to be visible: "a Memory screen lists every
  /// stored item **with its date**". Knowing *when* the app learned something
  /// is most of what makes a stored fact reviewable rather than unsettling.
  final DateTime createdAt;

  /// Reserved for the session that produced it (§9.5 `source_session_id`).
  /// Sessions arrive in Milestone 4; until then every memory comes from a
  /// typed thread and this is null.
  final String? sourceThreadTitle;
}
