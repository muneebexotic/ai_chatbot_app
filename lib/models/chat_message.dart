import 'package:cloud_firestore/cloud_firestore.dart';
import 'generated_image.dart';

class ChatMessage {
  final String text;
  final String sender; // 'user' or 'bot'
  final DateTime timestamp;
  final MessageType type; // New: message type
  final GeneratedImage? imageData; // New: for image messages
  String? _userPhotoUrl;
  String? get userPhotoUrl => _userPhotoUrl;

  ChatMessage({
    required this.text,
    required this.sender,
    DateTime? timestamp,
    this.type = MessageType.text, // Default to text
    this.imageData,
  }) : timestamp = timestamp ?? DateTime.now();

  // Factory constructor for image messages
  ChatMessage.image({
    required GeneratedImage image,
    required this.sender,
    DateTime? timestamp,
  }) : text = image.prompt,
       type = MessageType.image,
       imageData = image,
       timestamp = timestamp ?? DateTime.now();

  // Factory constructor for text messages (existing)
  ChatMessage.text({
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : type = MessageType.text,
       imageData = null,
       timestamp = timestamp ?? DateTime.now();

  /// Check if this is an image message
  bool get isImageMessage => type == MessageType.image && imageData != null;

  /// Check if this is a text message
  bool get isTextMessage => type == MessageType.text;

  /// Get display text for the message
  String get displayText {
    switch (type) {
      case MessageType.image:
        return imageData != null ? 'Generated image: ${imageData!.prompt}' : text;
      case MessageType.text:
        return text;
    }
  }

  /// Validation method to check if the message is valid
  bool isValid() {
    switch (type) {
      case MessageType.text:
        return text.trim().isNotEmpty && 
               sender.trim().isNotEmpty && 
               (sender == 'user' || sender == 'bot');
      case MessageType.image:
        return imageData != null && 
               imageData!.isValid() && 
               sender.trim().isNotEmpty && 
               (sender == 'user' || sender == 'bot');
    }
  }

  Map<String, dynamic> toMap() {
    final map = {
      'text': text,
      'sender': sender,
      'timestamp': timestamp,
      'type': type.name,
    };

    if (imageData != null) {
      map['imageData'] = imageData!.toMap();
    }

    return map;
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

    final messageType = MessageType.values.firstWhere(
      (type) => type.name == map['type'],
      orElse: () => MessageType.text,
    );

    GeneratedImage? imageData;
    if (messageType == MessageType.image && map['imageData'] != null) {
      imageData = GeneratedImage.fromMap(map['imageData']);
    }

    return ChatMessage(
      text: map['text'] ?? '',
      sender: map['sender'] ?? '',
      timestamp: parsedTimestamp,
      type: messageType,
      imageData: imageData,
    );
  }
}

enum MessageType {
  text,
  image;

  String get displayName {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.image:
        return 'Image';
    }
  }
}