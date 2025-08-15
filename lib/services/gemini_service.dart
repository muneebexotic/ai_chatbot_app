import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ai_chatbot_app/providers/settings_provider.dart';
import 'package:ai_chatbot_app/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GeminiService {
  late final GenerativeModel _model;
  final String? _systemPrompt;
  final SettingsProvider _settingsProvider;

  GeminiService(BuildContext context)
    : _settingsProvider = Provider.of<SettingsProvider>(context, listen: false),
      _systemPrompt = _getSystemPrompt(
        Provider.of<SettingsProvider>(context, listen: false).persona,
      ) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: 'AIzaSyAss8fSmad3Q60ynhwZPUnfKgsSuMZMtJY',
    );
    
    // Debug log to verify persona is being applied
    print('🎭 GeminiService initialized with persona: ${_settingsProvider.persona}');
    print('🎭 System prompt: $_systemPrompt');
  }

  // 🔥 FIXED: Get current system prompt (for real-time updates)
  String? get currentSystemPrompt {
    final currentPersona = _settingsProvider.persona;
    final prompt = _getSystemPrompt(currentPersona);
    print('🎭 Current persona: $currentPersona, Prompt: $prompt');
    return prompt;
  }

  // 🔥 NEW METHOD: Send message with full conversation history
  Future<String?> sendMessageWithHistory(List<ChatMessage> messages) async {
    try {
      final input = <Content>[];

      // Get the current system prompt (this ensures real-time persona updates)
      final systemPrompt = currentSystemPrompt;
      
      // Add system prompt if available
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        input.add(Content.text(systemPrompt));
        print('🎭 Using system prompt: $systemPrompt');
      } else {
        print('🎭 No system prompt - using default behavior');
      }

      // Convert chat messages to Gemini format
      for (final message in messages) {
        if (message.sender == 'user') {
          input.add(Content.text(message.text));
        } else if (message.sender == 'bot') {
          input.add(Content.model([TextPart(message.text)]));
        }
      }

      final response = await _model.generateContent(input);

      // Extract response text
      final candidates = response.candidates;
      if (candidates.isNotEmpty &&
          candidates[0].content.parts.isNotEmpty &&
          candidates[0].content.parts.first is TextPart) {
        final text = (candidates[0].content.parts.first as TextPart).text.trim();
        return text;
      }

      debugPrint('⚠️ Gemini returned no usable text');
      return null;
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
      return null;
    }
  }

  // 🔥 UPDATED: Keep old method for backward compatibility but add history parameter
  Future<String?> sendMessage(String prompt, {List<ChatMessage>? conversationHistory}) async {
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      // Create a new list with the conversation history + new message
      final updatedHistory = List<ChatMessage>.from(conversationHistory);
      updatedHistory.add(ChatMessage(text: prompt, sender: 'user'));
      return sendMessageWithHistory(updatedHistory);
    }
    
    // Fallback to old behavior for single messages
    try {
      final input = <Content>[];
      
      // Get current system prompt
      final systemPrompt = currentSystemPrompt;

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        input.add(Content.text('$systemPrompt\n$prompt'));
        print('🎭 Single message with system prompt: $systemPrompt');
      } else {
        input.add(Content.text(prompt));
        print('🎭 Single message without system prompt');
      }

      final response = await _model.generateContent(input);

      final candidates = response.candidates;
      if (candidates.isNotEmpty &&
          candidates[0].content.parts.isNotEmpty &&
          candidates[0].content.parts.first is TextPart) {
        final text = (candidates[0].content.parts.first as TextPart).text.trim();
        return text;
      }

      debugPrint('⚠️ Gemini returned no usable text');
      return null;
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
      return null;
    }
  }

  /// Generate a conversation title based on the conversation context
  Future<String?> generateConversationTitle(List<String> conversationMessages) async {
    try {
      // Take first 6 messages (3 exchanges) for context
      final contextMessages = conversationMessages.take(6).join('\n');
      
      final prompt = '''
Based on this conversation, generate a short, descriptive title (maximum 40 characters). 
The title should capture the main topic or question being discussed.
Do not include quotes or special characters.

Conversation:
$contextMessages

Generate a concise title:''';

      final input = [Content.text(prompt)];
      final response = await _model.generateContent(input);

      final candidates = response.candidates;
      if (candidates.isNotEmpty &&
          candidates[0].content.parts.isNotEmpty &&
          candidates[0].content.parts.first is TextPart) {
        String title = (candidates[0].content.parts.first as TextPart).text
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '')
            .replaceAll('Title:', '')
            .replaceAll('Generate a concise title:', '')
            .trim();
        
        // Clean up common prefixes
        if (title.startsWith('Title: ')) {
          title = title.substring(7);
        }
        
        // Ensure max length
        if (title.length > 40) {
          title = title.substring(0, 37) + '...';
        }
        
        return title.isNotEmpty ? title : null;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Title generation error: $e');
      return null;
    }
  }

  // 🔥 FIXED: Use the correct persona IDs and system prompts
  static String? _getSystemPrompt(String persona) {
    switch (persona) {
      case 'Default':
        return null; // No system prompt for default
      case 'Friendly Assistant':
        return 'You are a friendly and helpful assistant. Answer casually and politely with a warm, approachable tone. Be conversational and use everyday language while remaining helpful and informative.';
      case 'Strict Teacher':
        return 'You are a strict, no-nonsense teacher. Be firm, direct, and to the point. Focus on accuracy and educational value. Do not use jokes or casual language. Provide clear, structured answers with proper explanations.';
      case 'Wise Philosopher':
        return 'You are a wise philosopher with deep understanding of life and human nature. Speak in thoughtful, profound language. Offer insights that provoke reflection and deeper thinking. Use philosophical concepts and encourage contemplation.';
      case 'Sarcastic Developer':
        return 'You are a sarcastic but knowledgeable software engineer. Use dry humor, technical sarcasm, and witty remarks. Be helpful but with a cynical edge. Reference programming concepts and developer culture when appropriate.';
      case 'Motivational Coach':
        return 'You are an enthusiastic motivational coach! Respond with high energy, encouragement, and positivity. Use motivational language, push for action, and inspire confidence. Be supportive and uplifting in every response.';
      default:
        print('⚠️ Unknown persona: $persona, falling back to default');
        return null;
    }
  }
}