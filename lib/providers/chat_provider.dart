import 'package:ai_chatbot_app/providers/conversation_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../providers/auth_provider.dart';
import '../screens/subscription_screen.dart';

class ChatProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final List<ChatMessage> _messages = [];
  final String userId;
  final BuildContext context;
  late final GeminiService _geminiService;

  String? _conversationId;
  String? get conversationId => _conversationId;
  bool _titleGenerated = false;

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

  void updatePersona() {
    _geminiService = GeminiService(context);
    print('🎭 ChatProvider: GeminiService updated with new persona');
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
        conversationMessages.add('${message.sender}: ${message.text}');
      }

      String? aiTitle = await _geminiService.generateConversationTitle(
        conversationMessages,
      );

      final generatedTitle = (aiTitle != null && aiTitle.trim().isNotEmpty)
          ? aiTitle.trim()
          : _generateFallbackTitle(_messages.first.text);

      print('🧠 AI-generated title: $generatedTitle');

      await _firestoreService.updateConversationTitle(
        userId,
        _conversationId!,
        generatedTitle,
      );

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

  /// Check if user can send a message (usage limits)
  Future<bool> _canSendMessage() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return await authProvider.canSendMessage();
    } catch (e) {
      debugPrint('❌ Error checking message limit: $e');
      return true; // Default to allowing if check fails
    }
  }

  /// Show usage limit dialog
  Future<void> _showUsageLimitDialog(String limitType) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Daily Limit Reached',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'ve reached your daily $limitType limit for free users.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Premium for:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Unlimited messages\n• All personas\n• Unlimited images & voice\n• Priority support',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Later',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Upgrade',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> sendMessage(String userInput) async {
    // Check usage limits before sending
    final canSend = await _canSendMessage();
    if (!canSend) {
      await _showUsageLimitDialog('message');
      return;
    }

    if (_conversationId == null) {
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
      // Increment message usage
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.incrementMessageUsage();

      await _firestoreService.saveMessage(
        userId,
        _conversationId!,
        userMessage,
      );

      // Send to Gemini with conversation history
      final aiReply = await _geminiService.sendMessageWithHistory(_messages);

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

      // If Gemini fails, still show an error message
      final errorMessage = ChatMessage(
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return await authProvider.canUploadImage();
    } catch (e) {
      debugPrint('❌ Error checking image upload limit: $e');
      return true;
    }
  }

  /// Check if user can send voice messages
  Future<bool> canSendVoice() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return await authProvider.canSendVoice();
    } catch (e) {
      debugPrint('❌ Error checking voice limit: $e');
      return true;
    }
  }

  /// Increment image usage
  Future<void> incrementImageUsage() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.incrementImageUsage();
    } catch (e) {
      debugPrint('❌ Error incrementing image usage: $e');
    }
  }

  /// Increment voice usage
  Future<void> incrementVoiceUsage() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.incrementVoiceUsage();
    } catch (e) {
      debugPrint('❌ Error incrementing voice usage: $e');
    }
  }

  /// Handle image upload with usage tracking
  Future<void> handleImageUpload() async {
    final canUpload = await canUploadImage();
    if (!canUpload) {
      await _showUsageLimitDialog('image');
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
      await _showUsageLimitDialog('voice');
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
      print('🗑️ Conversation deleted');
    } catch (e) {
      print('❌ Error deleting conversation: $e');
    }
  }

  /// Wrapper for UI that expects `deleteChat()` method
  Future<void> deleteChat() async {
    await deleteConversation();
  }

  /// Get usage statistics for UI
  Map<String, dynamic> getUsageStats() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return {
        'isPremium': authProvider.isPremium,
        'remainingMessages': authProvider.paymentService.remainingMessages,
        'remainingImages': authProvider.paymentService.remainingImages,
        'remainingVoice': authProvider.paymentService.remainingVoice,
        'subscriptionStatus': authProvider.subscriptionStatus,
      };
    } catch (e) {
      debugPrint('❌ Error getting usage stats: $e');
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
