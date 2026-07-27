import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:ai_chatbot_app/core/logging/log.dart';
import 'package:ai_chatbot_app/models/chat_message.dart';

/// Returns the persona the user currently has selected.
///
/// A plain function, deliberately. It lets the service read a value that
/// changes over time without knowing where that value lives — no provider, no
/// widget tree, and trivially stubbable in a test as `() => 'Strict Teacher'`.
typedef PersonaResolver = String Function();

/// Talks to Gemini.
///
/// **No `BuildContext`, and no `flutter/material` import.** This class used to
/// take a `BuildContext` and call `Provider.of` in its own initialiser list,
/// which is F3 in the PRD: a service reaching into the widget tree. That makes
/// it untestable without pumping a widget, couples model access to a screen
/// being mounted, and is why this file previously imported Material at all.
///
/// PRD §9.1: services never import `flutter/material.dart` and never take a
/// `BuildContext`. Dependencies are constructor-injected as plain values.
///
/// This whole class is deleted in Milestone 3 when the gateway (R9.3) takes
/// over model access — but it should not be left violating the architecture
/// in the meantime, because "it's temporary" is how F3 survived this long.
class GeminiService {
  /// TRANSITIONAL — Milestone 0 only.
  ///
  /// The key that used to sit here as a literal was published to a public repo
  /// and must be treated as burned (see SECURITY-REMEDIATION.md). It is now
  /// supplied at build time so that no key exists in source.
  ///
  /// This is NOT the end state. Any key shipped in an APK is extractable, so
  /// --dart-define is a stopgap, not a fix. PRD F1/R9.3 move every model call
  /// behind the Supabase Edge Function gateway, which holds the key
  /// server-side; this whole class is deleted in Milestone 3.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;
  final PersonaResolver _persona;

  GeminiService({required PersonaResolver persona}) : _persona = persona {
    if (_apiKey.isEmpty) {
      // Fail closed and loudly. A silent empty key produces confusing 400s
      // from the API instead of naming the actual problem.
      throw StateError(
        'GEMINI_API_KEY was not provided at build time. Run with '
        '--dart-define=GEMINI_API_KEY=<key>. See README.md. This mechanism is '
        'temporary and is removed when the gateway lands (PRD R9.3).',
      );
    }

    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  /// The system prompt for the persona selected *right now*.
  ///
  /// Resolved per call rather than cached at construction, so changing persona
  /// takes effect on the next message instead of requiring the service to be
  /// rebuilt. The old code cached it in the constructor *and* recomputed it
  /// here, which is why persona changes needed a `updatePersona()` that threw
  /// the whole service away.
  String? get currentSystemPrompt => _getSystemPrompt(_persona());

  // 🔥 NEW METHOD: Send message with full conversation history
  Future<String?> sendMessageWithHistory(List<ChatMessage> messages) async {
    try {
      final input = <Content>[];

      // Get the current system prompt (this ensures real-time persona updates)
      final systemPrompt = currentSystemPrompt;

      // Add system prompt if available
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        input.add(Content.text(systemPrompt));
        Log.d('Using system prompt: $systemPrompt');
      } else {
        Log.d('No system prompt - using default behavior');
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
        final text = (candidates[0].content.parts.first as TextPart).text
            .trim();
        return text;
      }

      Log.d('Gemini returned no usable text');
      return null;
    } catch (e) {
      Log.d('Gemini error: $e');
      return null;
    }
  }

  // 🔥 UPDATED: Keep old method for backward compatibility but add history parameter
  Future<String?> sendMessage(
    String prompt, {
    List<ChatMessage>? conversationHistory,
  }) async {
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
        Log.d('Single message with system prompt: $systemPrompt');
      } else {
        input.add(Content.text(prompt));
        Log.d('Single message without system prompt');
      }

      final response = await _model.generateContent(input);

      final candidates = response.candidates;
      if (candidates.isNotEmpty &&
          candidates[0].content.parts.isNotEmpty &&
          candidates[0].content.parts.first is TextPart) {
        final text = (candidates[0].content.parts.first as TextPart).text
            .trim();
        return text;
      }

      Log.d('Gemini returned no usable text');
      return null;
    } catch (e) {
      Log.d('Gemini error: $e');
      return null;
    }
  }

  /// Generate a conversation title based on the conversation context
  Future<String?> generateConversationTitle(
    List<String> conversationMessages,
  ) async {
    try {
      // Take first 6 messages (3 exchanges) for context
      final contextMessages = conversationMessages.take(6).join('\n');

      final prompt =
          '''
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
          title = '${title.substring(0, 37)}...';
        }

        return title.isNotEmpty ? title : null;
      }

      return null;
    } catch (e) {
      Log.d('Title generation error: $e');
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
        Log.d('Unknown persona: $persona, falling back to default');
        return null;
    }
  }
}
