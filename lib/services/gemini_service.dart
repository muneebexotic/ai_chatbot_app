import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ai_chatbot_app/providers/settings_provider.dart';
import 'package:ai_chatbot_app/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GeminiService {
  late final GenerativeModel _model;
  final String? _systemPrompt;

  GeminiService(BuildContext context)
    : _systemPrompt = _getSystemPrompt(
        Provider.of<SettingsProvider>(context, listen: false).persona,
      ) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: 'AIzaSyAss8fSmad3Q60ynhwZPUnfKgsSuMZMtJY',
    );
  }

  // 🔥 NEW METHOD: Send message with full conversation history
  Future<String?> sendMessageWithHistory(List<ChatMessage> messages) async {
    try {
      final input = <Content>[];

      // Add system prompt if available
      if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
        input.add(Content.text(_systemPrompt!));
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

      if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
        input.add(Content.text('$_systemPrompt\n$prompt'));
      } else {
        input.add(Content.text(prompt));
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

  static String? _getSystemPrompt(String persona) {
    switch (persona) {
      case 'professional':
        return 'Respond concisely and formally like a professional assistant.';
      case 'funny':
        return 'Add humor to your answers and use casual language.';
      case 'friendly':
        return 'Be kind, warm, and friendly while helping the user.';
      case 'none':
      default:
        return null;
    }
  }
}