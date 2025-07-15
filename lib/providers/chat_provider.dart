import 'package:ai_chatbot_app/providers/conversation_provider.dart';
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

  String? _conversationId;
  String? get conversationId => _conversationId;
  bool _titleGenerated = false; // Track if title has been generated

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

  String _generateFallbackTitle(String text) {
    text = text.trim();
    if (text.length <= 30) return text;
    return text.substring(0, 30).split('\n').first + '...';
  }

  Future<void> startNewConversation() async {
    _conversationId = await _firestoreService.createConversation(userId);
    _messages.clear();
    _titleGenerated = false; // Reset title generation flag
    notifyListeners();
  }

  Future<void> loadConversation(String conversationId) async {
    _conversationId = conversationId;
    _messages.clear();
    _titleGenerated = true; // Existing conversations already have titles
    final fetched = await _firestoreService.getMessages(userId, conversationId);
    _messages.addAll(fetched);
    notifyListeners();
  }

  /// Generate AI title based on conversation context
  Future<void> _generateConversationTitle() async {
    if (_conversationId == null || _titleGenerated) return;

    try {
      // Get conversation messages for context
      final conversationMessages = <String>[];
      for (final message in _messages) {
        conversationMessages.add('${message.sender}: ${message.text}');
      }

      // Generate title using AI
      String? aiTitle = await _geminiService.generateConversationTitle(conversationMessages);
      
      final generatedTitle = (aiTitle != null && aiTitle.trim().isNotEmpty)
          ? aiTitle.trim()
          : _generateFallbackTitle(_messages.first.text);

      print('🧠 AI-generated title: $generatedTitle');

      // Update title in Firestore
      await _firestoreService.updateConversationTitle(
        userId,
        _conversationId!,
        generatedTitle,
      );

      // Refresh sidebar
      try {
        await Provider.of<ConversationsProvider>(
          context,
          listen: false,
        ).loadConversations();
      } catch (e) {
        debugPrint('⚠️ Could not refresh sidebar: $e');
      }

      _titleGenerated = true;
    } catch (e) {
      debugPrint('❌ Error generating title: $e');
    }
  }

  Future<void> sendMessage(String userInput) async {
    if (_conversationId == null) {
      // Create new conversation with placeholder title
      _conversationId = await _firestoreService.createConversationWithTitle(
        userId,
        'New Chat',
      );
      _messages.clear();
      _titleGenerated = false;
      notifyListeners();
    }

    final userMessage = ChatMessage(text: userInput, sender: 'user');
    _messages.add(userMessage);
    _setTyping(true);
    notifyListeners();
    print('✅ User message added: ${userMessage.text}');

    try {
      await _firestoreService.saveMessage(
        userId,
        _conversationId!,
        userMessage,
      );

      final aiReply = await _geminiService.sendMessage(userInput);

      final botReply = ChatMessage(
        text: aiReply ?? "Sorry, I couldn't understand that.",
        sender: 'bot',
      );

      _messages.add(botReply);
      notifyListeners();
      print('🤖 Gemini reply: ${botReply.text}');

      await _firestoreService.saveMessage(userId, _conversationId!, botReply);

      // Generate AI title after 2nd bot response (4 total messages)
      if (!_titleGenerated && _messages.length >= 4) {
        await _generateConversationTitle();
      }
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
      _titleGenerated = false;
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