import 'package:ai_chatbot_app/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

class ChatProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final List<ChatMessage> _messages = [];
  final String userId;
  final BuildContext context;
  late final GeminiService _geminiService;

  ChatProvider({required this.userId, required this.context}) {
    _geminiService = GeminiService(context);
    if (userId.isNotEmpty) {
      _loadMessages();
    }
  }

  List<ChatMessage> get messages => _messages;
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  void _setTyping(bool value) {
    _isTyping = value;
    notifyListeners();
  }

  Future<void> sendMessage(String userInput) async {
    final userMessage = ChatMessage(text: userInput, sender: 'user');
    _messages.add(userMessage);
    _setTyping(true);
    notifyListeners();
    print('✅ User message added: ${userMessage.text}');

    try {
      await _firestoreService.saveMessage(userId, userMessage);

      final aiReply = await _geminiService.sendMessage(userInput);

      final botReply = ChatMessage(
        text: aiReply ?? 'Sorry, I couldn’t understand that.',
        sender: 'bot',
      );

      _messages.add(botReply);
      notifyListeners();
      print('🤖 Gemini reply: ${botReply.text}');

      await _firestoreService.saveMessage(userId, botReply);
    } catch (e) {
      print('❌ Error in sendMessage: $e');
    } finally {
      _setTyping(false);
    }
  }

  Future<void> clearChat() async {
    _messages.clear();
    notifyListeners();
  }

  /// 🔥 Delete chat from Firestore + local memory
  Future<void> deleteChat() async {
    try {
      await _firestoreService.deleteAllMessages(userId);
      _messages.clear();
      notifyListeners();
      print('🗑️ All messages deleted for user $userId');
    } catch (e) {
      print('❌ Error deleting messages: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (_messages.isNotEmpty) return;
    try {
      final fetched = await _firestoreService.getMessages(userId);
      _messages.addAll(fetched);
      notifyListeners();
      print('📦 Messages loaded: ${fetched.length}');
    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }
}
