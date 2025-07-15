import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ConversationSummary {
  final String id;
  String title;
  final String createdAt;

  ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
  });
}

class ConversationsProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final String userId;
  List<ConversationSummary> _conversations = [];

  ConversationsProvider({required this.userId}) {
    loadConversations();
  }

  List<ConversationSummary> get conversations => _conversations;

  Future<void> loadConversations() async {
    final data = await _firestoreService.getConversations(userId);
    _conversations = data.map((map) {
      return ConversationSummary(
        id: map['id'],
        title: map['title'],
        createdAt: map['createdAt'],
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addConversation(String title) async {
    final id = await _firestoreService.createConversationWithTitle(userId, title);
    _conversations.insert(
      0,
      ConversationSummary(id: id, title: title, createdAt: DateTime.now().toIso8601String()),
    );
    notifyListeners();
  }

  Future<void> deleteConversation(String conversationId) async {
    await _firestoreService.deleteConversation(userId, conversationId);
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  Future<void> renameConversation(String conversationId, String newTitle) async {
    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex != -1) {
      _conversations[convoIndex].title = newTitle;
      // Optional: update in Firestore
      await _firestoreService.updateConversationTitle(userId, conversationId, newTitle);
      notifyListeners();
    }
  }
}
