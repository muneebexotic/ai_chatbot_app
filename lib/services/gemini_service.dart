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
      return response.text?.trim();
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
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
