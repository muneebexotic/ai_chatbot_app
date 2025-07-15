import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Create a new conversation with default title
  Future<String> createConversation(String userId) async {
    return createConversationWithTitle(userId, 'New Chat');
  }

  /// Create a new conversation with a custom title
  Future<String> createConversationWithTitle(String userId, String title) async {
    final docRef = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .add({
          'title': title,
          'createdAt': DateTime.now().toIso8601String(),
        });

    return docRef.id;
  }

  /// Save a message to a specific conversation
  Future<void> saveMessage(
    String userId,
    String conversationId,
    ChatMessage message,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
          'text': message.text,
          'sender': message.sender,
          'timestamp': message.timestamp.toIso8601String(),
        });
  }

  /// Get all messages for a specific conversation
  Future<List<ChatMessage>> getMessages(
    String userId,
    String conversationId,
  ) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    return snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList();
  }

  /// Get all conversation summaries (for sidebar list)
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'],
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  /// Update a conversation title
  Future<void> updateConversationTitle(
    String userId,
    String conversationId,
    String newTitle,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .update({'title': newTitle});
  }

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(String userId, String conversationId) async {
    final batch = _db.batch();
    final messagesRef = _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');

    final messagesSnapshot = await messagesRef.get();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final convoRef = _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId);

    batch.delete(convoRef);
    await batch.commit();
  }
}
