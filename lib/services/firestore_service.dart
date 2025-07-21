import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/app_user.dart';

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
    if (userId.isEmpty) {
      print('❌ Error: userId is empty in getConversations');
      return [];
    }

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

  /// Search conversations by title (server-side search for large datasets)
  Future<List<Map<String, dynamic>>> searchConversations(
    String userId,
    String searchQuery,
  ) async {
    if (searchQuery.trim().isEmpty) {
      return getConversations(userId);
    }

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .where('title', isGreaterThanOrEqualTo: searchQuery)
        .where('title', isLessThan: searchQuery + '\uf8ff')
        .orderBy('title')
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

  /// Save AppUser to Firestore (overwrite or merge)
  Future<void> saveUser(AppUser user) async {
    try {
      await _db.collection('users').doc(user.uid).set(
        user.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving user: $e');
      rethrow;
    }
  }

  /// Get AppUser from Firestore
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(uid, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }
}
