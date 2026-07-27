// `foundation`, not `material`. This class holds state; it does not build
// widgets, and importing Material is how it drifted into showing dialogs.
import 'package:flutter/foundation.dart';

import 'package:ai_chatbot_app/core/logging/log.dart';
import '../models/chat_message.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../providers/auth_provider.dart';

/// Chat state for one user.
///
/// **No `BuildContext`.** It previously held one and used it to read other
/// providers, to build an `AlertDialog`, and to push a route — F3, and the
/// reason every method here needed a `mounted` guard. Dependencies are now
/// constructor-injected, so this class can be constructed and driven in a
/// test with no widget tree at all.
class ChatProvider with ChangeNotifier {
  ChatProvider({
    required this.userId,
    required AuthProvider auth,
    required PersonaResolver persona,
    Future<void> Function()? onConversationsChanged,
  }) : _auth = auth,
       _onConversationsChanged = onConversationsChanged,
       _geminiService = GeminiService(persona: persona);

  final FirestoreService _firestoreService = FirestoreService();
  final List<ChatMessage> _messages = [];
  final String userId;
  final AuthProvider _auth;
  final GeminiService _geminiService;

  /// Lets the conversation list refresh after a title is generated, without
  /// this class reaching for another provider through a context.
  final Future<void> Function()? _onConversationsChanged;

  String? _conversationId;
  String? get conversationId => _conversationId;
  bool _titleGenerated = false;

  List<ChatMessage> get messages => _messages;
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  /// Set when an action was refused for quota, naming what was blocked
  /// ('message', 'voice', …). The UI watches this and decides what to show.
  ///
  /// State signals an event; the widget layer renders it. Previously this
  /// class built the paywall dialog itself, which meant a state class chose
  /// the copy, the colours, and the navigation target — and made R8.3's
  /// "paywall appears at exactly two moments" impossible to enforce or test.
  String? _quotaBlockedFor;
  String? get quotaBlockedFor => _quotaBlockedFor;

  void _blockOnQuota(String limitType) {
    _quotaBlockedFor = limitType;
    notifyListeners();
  }

  /// Called by the UI once it has shown whatever the block warrants.
  void acknowledgeQuotaBlock() {
    if (_quotaBlockedFor == null) return;
    _quotaBlockedFor = null;
    notifyListeners();
  }

  void _setTyping(bool value) {
    _isTyping = value;
    notifyListeners();
  }

  /// Persona is resolved per call inside [GeminiService], so switching persona
  /// needs no rebuild. This only nudges listeners so the UI reflects the
  /// change immediately.
  void updatePersona() {
    Log.d('ChatProvider: persona changed');
    notifyListeners();
  }

  String _generateFallbackTitle(String text) {
    text = text.trim();
    if (text.length <= 30) return text;
    return '${text.substring(0, 30).split('\n').first}...';
  }

  Future<void> startNewConversation() async {
    _conversationId = await _firestoreService.createConversation(userId);
    _messages.clear();
    _titleGenerated = false;
    notifyListeners();
  }

  Future<void> loadConversation(String conversationId) async {
    _conversationId = conversationId;
    _messages.clear();
    _titleGenerated = true;
    final fetched = await _firestoreService.getMessages(userId, conversationId);
    _messages.addAll(fetched);
    notifyListeners();
  }

  /// Generate AI title based on conversation context
  Future<void> _generateConversationTitle() async {
    if (_conversationId == null || _titleGenerated) return;

    try {
      final conversationMessages = <String>[];
      for (final message in _messages) {
        conversationMessages.add('${message.sender}: ${message.displayText}');
      }

      String? aiTitle = await _geminiService.generateConversationTitle(
        conversationMessages,
      );

      final generatedTitle = (aiTitle != null && aiTitle.trim().isNotEmpty)
          ? aiTitle.trim()
          : _generateFallbackTitle(_messages.first.displayText);

      Log.d('AI-generated title: $generatedTitle');

      await _firestoreService.updateConversationTitle(
        userId,
        _conversationId!,
        generatedTitle,
      );

      try {
        await _onConversationsChanged?.call();
      } catch (e) {
        Log.d('Could not refresh conversation list: $e');
      }

      _titleGenerated = true;
    } catch (e) {
      Log.d('Error generating title: $e');
    }
  }

  /// Check if user can send a message (usage limits)
  Future<bool> _canSendMessage() async {
    try {
      return await _auth.canSendMessage();
    } catch (e) {
      Log.d('Error checking message limit: $e');
      return true; // Default to allowing if check fails
    }
  }

  Future<void> sendMessage(String userInput) async {
    // Check usage limits before sending
    final canSend = await _canSendMessage();
    if (!canSend) {
      _blockOnQuota('message');
      return;
    }
    // Continue with normal text message flow
    if (_conversationId == null) {
      _conversationId = await _firestoreService.createConversationWithTitle(
        userId,
        'New Chat',
      );
      _messages.clear();
      _titleGenerated = false;
      notifyListeners();
    }

    final userMessage = ChatMessage.text(text: userInput, sender: 'user');
    _messages.add(userMessage);
    _setTyping(true);
    notifyListeners();
    Log.d('User message added: ${userMessage.text}');

    try {
      // Increment message usage (authProvider resolved at method entry)
      await _auth.incrementMessageUsage();

      await _firestoreService.saveMessage(
        userId,
        _conversationId!,
        userMessage,
      );

      // Send to Gemini with conversation history
      final aiReply = await _geminiService.sendMessageWithHistory(_messages);

      final botReply = ChatMessage.text(
        text: aiReply ?? "Sorry, I couldn't understand that.",
        sender: 'bot',
      );

      _messages.add(botReply);
      notifyListeners();
      Log.d('Gemini reply: ${botReply.text}');

      await _firestoreService.saveMessage(userId, _conversationId!, botReply);

      // Generate AI title after 2nd bot response (4 total messages)
      if (!_titleGenerated && _messages.length >= 4) {
        await _generateConversationTitle();
      }
    } catch (e) {
      Log.d('Error in sendMessage: $e');

      // If Gemini fails, still show an error message
      final errorMessage = ChatMessage.text(
        text:
            "Sorry, I'm having trouble responding right now. Please try again.",
        sender: 'bot',
      );

      _messages.add(errorMessage);
      notifyListeners();
    } finally {
      _setTyping(false);
    }
  }

  /// Check if user can upload images
  Future<bool> canUploadImage() async {
    try {
      return await _auth.canUploadImage();
    } catch (e) {
      Log.d('Error checking image upload limit: $e');
      return true;
    }
  }

  /// Check if user can send voice messages
  Future<bool> canSendVoice() async {
    try {
      return await _auth.canSendVoice();
    } catch (e) {
      Log.d('Error checking voice limit: $e');
      return true;
    }
  }

  /// Increment image usage
  Future<void> incrementImageUsage() async {
    try {
      await _auth.incrementImageUsage();
    } catch (e) {
      Log.d('Error incrementing image usage: $e');
    }
  }

  /// Increment voice usage
  Future<void> incrementVoiceUsage() async {
    try {
      await _auth.incrementVoiceUsage();
    } catch (e) {
      Log.d('Error incrementing voice usage: $e');
    }
  }

  /// Handle image upload with usage tracking
  Future<void> handleImageUpload() async {
    final canUpload = await canUploadImage();
    if (!canUpload) {
      _blockOnQuota('image');
      return;
    }

    // Proceed with image upload logic
    await incrementImageUsage();

    // Your existing image upload logic here...
  }

  /// Handle voice message with usage tracking
  Future<void> handleVoiceMessage() async {
    final canSend = await canSendVoice();
    if (!canSend) {
      _blockOnQuota('voice');
      return;
    }

    // Proceed with voice message logic
    await incrementVoiceUsage();

    // Your existing voice message logic here...
  }

  Future<void> deleteConversation() async {
    if (_conversationId == null) return;
    try {
      await _firestoreService.deleteConversation(userId, _conversationId!);
      _messages.clear();
      _conversationId = null;
      _titleGenerated = false;
      notifyListeners();
      Log.d('Conversation deleted');
    } catch (e) {
      Log.d('Error deleting conversation: $e');
    }
  }

  /// Wrapper for UI that expects `deleteChat()` method
  Future<void> deleteChat() async {
    await deleteConversation();
  }

  /// Get usage statistics for UI
  Map<String, dynamic> getUsageStats() {
    try {
      return {
        'isPremium': _auth.isPremium,
        'remainingMessages': _auth.paymentService.remainingMessages,
        'remainingImages': _auth.paymentService.remainingImages,
        'remainingVoice': _auth.paymentService.remainingVoice,
        'subscriptionStatus': _auth.subscriptionStatus,
      };
    } catch (e) {
      Log.d('Error getting usage stats: $e');
      return {
        'isPremium': false,
        'remainingMessages': 0,
        'remainingImages': 0,
        'remainingVoice': 0,
        'subscriptionStatus': 'Free Plan',
      };
    }
  }
}
