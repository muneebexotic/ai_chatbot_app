import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveMessage(String userId, ChatMessage message) async {
    await _db
        .collection('chats')
        .doc(userId)
        .collection('messages')
        .add({
          'text': message.text,
          'sender': message.sender,
          'timestamp': message.timestamp.toIso8601String(),
        });
  }

  Future<List<ChatMessage>> getMessages(String userId) async {
    final snapshot = await _db
        .collection('chats')
        .doc(userId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ChatMessage.fromMap(data);
    }).toList();
  }

  /// 🔥 Delete all chat messages for a user from Firestore
  Future<void> deleteAllMessages(String userId) async {
    final batch = _db.batch();
    final messagesRef = _db.collection('chats').doc(userId).collection('messages');
    final snapshot = await messagesRef.get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
