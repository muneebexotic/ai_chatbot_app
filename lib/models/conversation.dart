class Conversation {
  final String id;
  final String title;
  final String createdAt;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory Conversation.fromMap(String id, Map<String, dynamic> data) {
    return Conversation(
      id: id,
      title: data['title'] ?? 'Untitled',
      createdAt: data['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdAt': createdAt,
    };
  }
}
