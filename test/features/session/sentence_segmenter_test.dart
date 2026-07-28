import 'package:flutter_test/flutter_test.dart';

import 'package:speakwise/features/session/domain/sentence_segmenter.dart';

/// R4.2.4 — "beginning text-to-speech on the first complete sentence rather
/// than waiting for the full response".
///
/// This is the only piece of the latency budget that can be tested off-device.
/// The rest of it is a stopwatch on a phone (`qa/m4-device-pass.md`), so the
/// part that *can* be pinned is pinned hard: an off-by-one here is a spoken
/// reply that repeats a clause or drops one, and both would be blamed on the
/// model rather than on this file.
void main() {
  group('a sentence is emitted as soon as it closes', () {
    test('one sentence arriving in fragments emits once, when it ends', () {
      final segmenter = SentenceSegmenter();

      expect(segmenter.add('That is '), isEmpty);
      expect(segmenter.add('a good '), isEmpty);
      expect(segmenter.add('example'), isEmpty);
      // The period alone is not enough — see the note in _findCut. A reply that
      // currently ends in "." might be "3." at the head of a list.
      expect(segmenter.add('.'), isEmpty);
      expect(segmenter.add(' Now'), ['That is a good example.']);
    });

    test('the leftover stays buffered and is not emitted twice', () {
      final segmenter = SentenceSegmenter();
      expect(segmenter.add('First one. Second one'), ['First one.']);
      expect(segmenter.flush(), 'Second one');
      expect(segmenter.flush(), '');
    });

    test('several endings in one chunk all emit, in order', () {
      // A single network chunk routinely carries more than one sentence.
      // Returning only the first would silently truncate the spoken reply while
      // the on-screen transcript stayed correct.
      final segmenter = SentenceSegmenter();
      expect(
        segmenter.add('One. Two? Three! Four'),
        ['One.', 'Two?', 'Three!'],
      );
      expect(segmenter.flush(), 'Four');
    });

    test('grouped terminators emit as one sentence', () {
      final segmenter = SentenceSegmenter();
      expect(segmenter.add('Really?! Yes'), ['Really?!']);

      final ellipsis = SentenceSegmenter();
      expect(ellipsis.add('Well... maybe'), ['Well...']);
    });

    test('a newline ends a sentence even without punctuation', () {
      final segmenter = SentenceSegmenter();
      expect(segmenter.add('First line\nSecond'), ['First line']);
    });
  });

  group('abbreviations do not end a sentence', () {
    List<String> segment(String text) {
      final segmenter = SentenceSegmenter();
      final out = segmenter.add(text);
      final rest = segmenter.flush();
      return [...out, if (rest.isNotEmpty) rest];
    }

    test('common abbreviations stay inside their sentence', () {
      expect(
        segment('Use a concrete example, e.g. the migration you led.'),
        ['Use a concrete example, e.g. the migration you led.'],
      );
      expect(
        segment('Ask Dr. Kapoor about it first.'),
        ['Ask Dr. Kapoor about it first.'],
      );
      expect(segment('Ship it vs. rewrite it.'), ['Ship it vs. rewrite it.']);
    });

    test('an initial is not a sentence ending', () {
      expect(segment('That was J. Smith speaking.'), ['That was J. Smith speaking.']);
    });

    test('a real sentence ending after an abbreviation still splits', () {
      expect(
        segment('Keep it short, e.g. two lines. Then stop.'),
        ['Keep it short, e.g. two lines.', 'Then stop.'],
      );
    });

    test('a period with no space after it is not a boundary', () {
      // Decimals and version numbers.
      expect(segment('It grew 3.5 times.'), ['It grew 3.5 times.']);
    });
  });

  group('the soft limit rescues unpunctuated output', () {
    const run =
        'so the first thing I would do is look at the data, and then '
        'I would talk to the team about it';

    test('a clause mark inside the window is preferred', () {
      // Some models produce long unpunctuated stretches. Without this, the one
      // case R4.2.4 exists to prevent — nothing spoken until the stream closes
      // — would become the default for those models.
      //
      // The comma sits at character 49, so a 60-character window can reach it.
      final segmenter = SentenceSegmenter(softLimit: 60);
      final emitted = segmenter.add(run);

      expect(emitted, isNotEmpty);
      expect(emitted.first, 'so the first thing I would do is look at the data,');
    });

    test('with no clause mark in reach it falls back to a word break', () {
      // A 40-character window stops short of the comma. Cutting at the last
      // space is still a speakable phrase; cutting at 40 exactly would be
      // "...look a".
      final segmenter = SentenceSegmenter(softLimit: 40);
      final emitted = segmenter.add(run);

      expect(emitted, isNotEmpty);
      expect(emitted.first, 'so the first thing I would do is look');
    });

    test('it never cuts mid-word', () {
      // "the migrat" spoken aloud is worse than a late start.
      final segmenter = SentenceSegmenter(softLimit: 30);
      final emitted = segmenter.add(
        'we spent about three weeks on the migration and it went fine overall',
      );
      for (final sentence in emitted) {
        expect(sentence.endsWith(' '), isFalse);
        // Whatever was cut, the last token must be a whole word.
        expect(RegExp(r'[a-z]$|[,;:]$').hasMatch(sentence), isTrue,
            reason: 'cut mid-word: "$sentence"');
      }
    });

    test('a short buffer is left alone', () {
      final segmenter = SentenceSegmenter(softLimit: 200);
      expect(segmenter.add('short and unfinished'), isEmpty);
    });
  });

  group('nothing is lost when the stream ends abruptly', () {
    test('flush returns a reply that never had terminal punctuation', () {
      // Every reply truncated by max_tokens looks like this. The gateway
      // reports `truncated`, and the last words exist only in the buffer.
      final segmenter = SentenceSegmenter();
      expect(segmenter.add('I think the strongest part of that answer was'), isEmpty);
      expect(
        segmenter.flush(),
        'I think the strongest part of that answer was',
      );
    });

    test('flush on an empty segmenter is empty, not whitespace', () {
      final segmenter = SentenceSegmenter();
      segmenter.add('Done. ');
      expect(segmenter.flush(), '');
      expect(segmenter.isEmpty, isTrue);
    });

    test('whitespace-only input never produces an empty utterance', () {
      // Speaking "" is a no-op that still costs a platform round trip inside
      // the latency budget.
      final segmenter = SentenceSegmenter();
      expect(segmenter.add('   \n  '), isEmpty);
      expect(segmenter.flush(), '');
    });
  });
}
