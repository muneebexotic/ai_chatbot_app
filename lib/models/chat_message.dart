import 'package:cloud_firestore/cloud_firestore.dart';

/// A single turn in a thread.
///
/// Text only. PRD §2.2 cuts image generation outright, so the `MessageType`
/// enum and the `GeneratedImage` payload that used to live here are gone.
///
/// Image *understanding* (§5.4) is a different feature and is not modelled
/// yet: it arrives with the gateway in Milestone 3, and when it does the
/// attachment is a Supabase Storage reference behind a signed URL, not an
/// embedded blob. Adding a speculative field for it now would be guessing at
/// a shape the server has not defined.
///
/// `fromMap` still tolerates the old persisted `type` and `imageData` keys —
/// see the note there. Real users had messages written in the old format.
class ChatMessage {
  ChatMessage({
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Named constructor kept because call sites read better with it, and
  /// because removing it would churn files this milestone has no other reason
  /// to touch.
  ChatMessage.text({
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;

  /// `'user'` or `'bot'`.
  final String sender;

  final DateTime timestamp;

  String? _userPhotoUrl;
  String? get userPhotoUrl => _userPhotoUrl;

  /// What to render. Retained so call sites need not care whether a message
  /// has a display form distinct from its raw text.
  String get displayText => text;

  bool isValid() =>
      text.trim().isNotEmpty &&
      sender.trim().isNotEmpty &&
      (sender == 'user' || sender == 'bot');

  Map<String, dynamic> toMap() => {
    'text': text,
    'sender': sender,
    'timestamp': timestamp,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];

    final DateTime parsedTimestamp;
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now();
    }

    // Messages written before image generation was cut may still carry
    // `type: 'image'` and an `imageData` map. Both are ignored rather than
    // rejected: the row keeps its text and timestamp and renders as an
    // ordinary message, which is better than throwing on a user's history.
    return ChatMessage(
      text: map['text'] ?? '',
      sender: map['sender'] ?? '',
      timestamp: parsedTimestamp,
    );
  }
}
