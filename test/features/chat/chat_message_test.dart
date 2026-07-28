import 'package:flutter_test/flutter_test.dart';

import 'package:ai_chatbot_app/features/chat/domain/chat_message.dart';

/// R7.4.2: "Streaming responses reveal by **word**, not by character, with no
/// cursor artefact and no layout jump."
///
/// The transport does not cooperate with that. Groq forwards model tokens,
/// which are sub-word — a reply arrives as "Inter", "view", "ing". Rendering
/// them as they land is the character-by-character typewriter the requirement
/// rules out, and it is genuinely worse to read: a word that materialises in
/// three pieces makes the eye re-fixate three times.
///
/// So the reveal is computed rather than transported, and this is where that
/// computation is pinned.
void main() {
  ChatMessage streaming(String content) => ChatMessage(
    id: 'm1',
    role: ChatRole.assistant,
    content: content,
    createdAt: DateTime(2026),
    isStreaming: true,
  );

  ChatMessage settled(String content) => ChatMessage(
    id: 'm1',
    role: ChatRole.assistant,
    content: content,
    createdAt: DateTime(2026),
  );

  group('R7.4.2 — reveal by word', () {
    test('a partial word is withheld while streaming', () {
      expect(streaming('Tell me about inter').visibleContent, 'Tell me about');
    });

    test('a completed word appears as soon as the space arrives', () {
      expect(
        streaming('Tell me about interviews ').visibleContent,
        'Tell me about interviews',
      );
    });

    test('the first token alone shows nothing', () {
      // Two tokens into a reply there is not yet a whole word to show, and
      // showing "Wh" is the artefact the requirement is about.
      expect(streaming('Wh').visibleContent, '');
      expect(streaming('What').visibleContent, '');
    });

    test('a newline counts as a word boundary', () {
      // Otherwise a reply that opens with a heading holds the entire first
      // line back until the second line starts.
      expect(streaming('## Practice\nStart by').visibleContent, '## Practice\nStart');
    });

    test('once settled, everything shows including a trailing fragment', () {
      // A model cut off at max_tokens ends mid-word. Withholding that fragment
      // forever would silently drop text the user paid for.
      expect(settled('Tell me about inter').visibleContent, 'Tell me about inter');
    });

    test('the reveal only ever grows', () {
      // The property that matters for "no layout jump": text must never get
      // shorter between frames, or the paragraph reflows backwards.
      const full = 'Design a system that scales to ten thousand users per day';
      var previous = 0;
      for (var i = 1; i <= full.length; i++) {
        final visible = streaming(full.substring(0, i)).visibleContent.length;
        expect(
          visible,
          greaterThanOrEqualTo(previous),
          reason: 'visible text shrank at prefix length $i',
        );
        previous = visible;
      }
      expect(settled(full).visibleContent, full);
    });
  });

  group('identity', () {
    test('a longer copy of the same message is not equal to the shorter one', () {
      // The list diffs on this. If a growing message compared equal to itself,
      // the transcript would stop repainting mid-reply.
      final a = streaming('Tell me ');
      final b = a.copyWith(content: 'Tell me about ');
      expect(a == b, isFalse);
    });

    test('settling changes identity even when the text does not', () {
      final a = streaming('Tell me about it ');
      expect(a == a.copyWith(isStreaming: false), isFalse);
    });
  });
}
