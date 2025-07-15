import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

class ChatProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final List<ChatMessage> _messages = [];
  final String userId;
  final BuildContext context;
  late final GeminiService _geminiService;

  String? _conversationId;
  String? get conversationId => _conversationId;

  ChatProvider({required this.userId, required this.context}) {
    _geminiService = GeminiService(context);
  }

  List<ChatMessage> get messages => _messages;
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  void _setTyping(bool value) {
    _isTyping = value;
    notifyListeners();
  }

  Future<void> startNewConversation() async {
    _conversationId = await _firestoreService.createConversation(userId);
    _messages.clear();
    notifyListeners();
  }

  Future<void> loadConversation(String conversationId) async {
    _conversationId = conversationId;
    _messages.clear();
    final fetched = await _firestoreService.getMessages(userId, conversationId);
    _messages.addAll(fetched);
    notifyListeners();
  }

  Future<void> sendMessage(String userInput) async {
    if (_conversationId == null) {
      await startNewConversation();
    }

    final userMessage = ChatMessage(text: userInput, sender: 'user');
    _messages.add(userMessage);
    _setTyping(true);
    notifyListeners();
    print('✅ User message added: ${userMessage.text}');

    try {
      await _firestoreService.saveMessage(userId, _conversationId!, userMessage);

      final aiReply = await _geminiService.sendMessage(userInput);

      final botReply = ChatMessage(
        text: aiReply ?? 'Sorry, I couldn’t understand that.',
        sender: 'bot',
      );

      _messages.add(botReply);
      notifyListeners();
      print('🤖 Gemini reply: ${botReply.text}');

      await _firestoreService.saveMessage(userId, _conversationId!, botReply);
    } catch (e) {
      print('❌ Error in sendMessage: $e');
    } finally {
      _setTyping(false);
    }
  }

  Future<void> deleteConversation() async {
    if (_conversationId == null) return;
    try {
      await _firestoreService.deleteConversation(userId, _conversationId!);
      _messages.clear();
      _conversationId = null;
      notifyListeners();
      print('🗑️ Conversation deleted');
    } catch (e) {
      print('❌ Error deleting conversation: $e');
    }
  }

  /// 👇 Wrapper for UI that expects `deleteChat()` method
  Future<void> deleteChat() async {
    await deleteConversation();
  }
}
