import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ai_chatbot_app/providers/settings_provider.dart';
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

  Future<String?> sendMessage(String prompt) async {
    try {
      final input = <Content>[];

      if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
        input.add(Content.text('$_systemPrompt\n$prompt'));
      } else {
        input.add(Content.text(prompt));
      }

      final response = await _model.generateContent(input);

      // ✅ Proper extraction for Gemini 2.5
      final candidates = response.candidates;
      if (candidates.isNotEmpty &&
          candidates[0].content.parts.isNotEmpty &&
          candidates[0].content.parts.first is TextPart) {
        final text = (candidates[0].content.parts.first as TextPart).text
            .trim();
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
        return null; // 👈 No system prompt for default
    }
  }
}