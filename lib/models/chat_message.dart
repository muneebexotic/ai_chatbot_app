import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String text;
  final String sender; // 'user' or 'bot'
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'sender': sender,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];

    DateTime parsedTimestamp;
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now(); // fallback
    }

    return ChatMessage(
      text: map['text'] ?? '',
      sender: map['sender'] ?? '',
      timestamp: parsedTimestamp,
    );
  }
}
