import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:speakwise/core/speech_metrics/metrics_engine.dart';
import 'package:speakwise/core/speech_metrics/pace_band.dart';
import 'package:speakwise/core/speech_metrics/speech_metrics.dart';
import 'package:speakwise/core/speech_metrics/transcript.dart';

/// R4.3.1, and §14's "metrics correct against a hand-checked transcript".
///
/// This file is the reason DECISIONS D2's mitigation is real rather than
/// stated. D2 makes this engine Drill Mode's scoring layer and Drill Mode the
/// free tier, then notes that Drill Mode ships a milestone *after* the engine —
/// so the engine has to be provably correct before its only other consumer
/// exists. Everything here runs without a widget tree, a database, or a
/// network, which is the property that makes that possible.
void main() {
  const engine = MetricsEngine();

  TranscriptTurn turn(
    Speaker speaker,
    String text, {
    required int startSeconds,
    required int durationSeconds,
  }) => TranscriptTurn(
    speaker: speaker,
    text: text,
    startOffset: Duration(seconds: startSeconds),
    duration: Duration(seconds: durationSeconds),
  );

  group('tokenizer', () {
    test('keeps internal apostrophes and hyphens as one word', () {
      expect(MetricsEngine.tokenize("don't"), ["don't"]);
      expect(MetricsEngine.tokenize('well-known'), ['well-known']);
      // A curly apostrophe is what a phone keyboard and most recognisers
      // actually produce, so treating only the straight one would split
      // "don’t" into two words and inflate every count on real input.
      expect(MetricsEngine.tokenize('don’t'), ['don’t']);
    });

    test('drops punctuation and folds case', () {
      expect(
        MetricsEngine.tokenize('Um, so... I built THAT!'),
        ['um', 'so', 'i', 'built', 'that'],
      );
    });

    test('a trailing hyphen or apostrophe is a separator, not part of the word', () {
      expect(MetricsEngine.tokenize('wait- what'), ['wait', 'what']);
    });

    test('digits count as words, because spoken numbers are words', () {
      expect(MetricsEngine.tokenize('about 20 people'), ['about', '20', 'people']);
    });
  });

  group('a hand-checked transcript (§14)', () {
    // Every expected value below was computed by hand from these four turns
    // before the engine was run against them.
    final turns = [
      turn(
        Speaker.partner,
        'Tell me about a project you are proud of.',
        startSeconds: 0,
        durationSeconds: 4,
      ),
      turn(
        Speaker.user,
        'Um, so I built a, like, scheduling tool for my team. '
        'It actually saved us time.',
        startSeconds: 5,
        durationSeconds: 10,
      ),
      turn(
        Speaker.partner,
        'What was the hardest part?',
        startSeconds: 16,
        durationSeconds: 3,
      ),
      // Starts at 18s while the partner runs to 19s — a barge-in (R4.2.3).
      turn(
        Speaker.user,
        'The hardest part was, you know, getting the data right.',
        startSeconds: 18,
        durationSeconds: 8,
      ),
    ];

    final metrics = engine.compute(turns, locale: 'en');

    test('speaking time is split by speaker, not by turn count', () {
      expect(metrics.userSpeakingTime, const Duration(seconds: 18));
      expect(metrics.partnerSpeakingTime, const Duration(seconds: 7));
      expect(metrics.talkTimeRatio, closeTo(18 / 25, 0.0001));
    });

    test('words and unique words count the user only', () {
      // 16 tokens in the first user turn, 10 in the second.
      expect(metrics.wordsSpoken, 26);
      // "the" repeats once inside the second turn; nothing else repeats.
      expect(metrics.uniqueWords, 25);
      expect(metrics.vocabularyVariety, closeTo(25 / 26, 0.0001));
    });

    test('pace is words over speaking time, not over session length', () {
      // 26 words / 0.3 min = 86.67. Over the 26s session it would read 60,
      // which would punish the user for the 7s they spent listening.
      expect(metrics.wordsPerMinute, closeTo(86.67, 0.01));
      expect(metrics.paceBand, PaceBand.slow);
    });

    test('fillers are counted with their disqualifiers applied', () {
      // "um" always. "like" between "a" and "scheduling" is a filler.
      // "you know" before "getting" is a filler.
      // "It actually saved us time" is NOT — "actually" is doing adverb work
      // mid-clause, and counting it would be advice the user cannot act on.
      expect(metrics.fillerBreakdown, {'um': 1, 'like': 1, 'you know': 1});
      expect(metrics.fillerCount, 3);
      expect(metrics.fillersMeasured, isTrue);
    });

    test('longest unbroken stretch is the longest single user turn', () {
      expect(metrics.longestUnbrokenStretch, const Duration(seconds: 10));
    });

    test('a barge-in is counted as a barge-in, not as a negative latency', () {
      // One real answer gap (4s → 5s). The second user turn began before the
      // partner finished, so it is an interruption and is excluded from the
      // mean rather than dragging it below zero.
      expect(metrics.averageResponseLatency, const Duration(seconds: 1));
      expect(metrics.bargeInCount, 1);
      expect(metrics.userTurnCount, 2);
    });

    test('duration falls back to the last turn ending when none is given', () {
      expect(metrics.duration, const Duration(seconds: 26));
    });

    test('an explicit session duration wins over the derived one', () {
      // A session that ends in silence is longer than its last turn, and the
      // wall clock is the truth for §8's minute quota.
      final withDuration = engine.compute(
        turns,
        locale: 'en',
        sessionDuration: const Duration(seconds: 40),
      );
      expect(withDuration.duration, const Duration(seconds: 40));
    });
  });

  group('filler disqualifiers — the cases a word list gets wrong', () {
    int fillers(String text) => engine
        .compute([
          turn(Speaker.user, text, startSeconds: 0, durationSeconds: 10),
        ], locale: 'en')
        .fillerCount;

    test('"like" as a verb is not a filler', () {
      expect(fillers('I like coffee'), 0);
      expect(fillers('we really like the design'), 0);
      expect(fillers('would you like to start'), 0);
      expect(fillers("I don't like that answer"), 0);
    });

    test('"like" as a preposition is not a filler', () {
      expect(fillers('it sounds like rain'), 0);
      expect(fillers('that looks like a bug'), 0);
      expect(fillers('it felt like an interview'), 0);
    });

    test('"like" as a discourse filler is a filler', () {
      expect(fillers('it was, like, really hard'), 1);
      expect(fillers('there were like twenty people'), 1);
    });

    test('"you know" introducing a clause is not a filler', () {
      expect(fillers('do you know what time it is'), 0);
      expect(fillers('you know that already'), 0);
    });

    test('bare "you know" is a filler', () {
      expect(fillers('it was, you know, complicated'), 1);
    });

    test('"actually" is scored on position, not on neighbours', () {
      // Mid-clause adverb — real work.
      expect(fillers('the numbers actually went up'), 0);
      expect(fillers('it actually saved us time'), 0);
      // Clause-initial — filler.
      expect(fillers('actually I think it went well'), 1);
      expect(fillers('and actually that was the problem'), 1);
    });

    test('"sort of" and "kind of" as nouns are not fillers', () {
      expect(fillers('what kind of role is it'), 0);
      expect(fillers('a sort of prototype'), 0);
      expect(fillers('it was sort of unclear'), 1);
    });

    test('a multi-word filler is counted once, not as its parts', () {
      // "you know" must not also register as two single-word matches, and
      // nothing inside a matched phrase may be re-matched.
      final metrics = engine.compute([
        turn(
          Speaker.user,
          'you know, um, you know, it was fine',
          startSeconds: 0,
          durationSeconds: 10,
        ),
      ], locale: 'en');
      expect(metrics.fillerBreakdown, {'you know': 2, 'um': 1});
      expect(metrics.fillerCount, 3);
    });

    test('hesitation sounds are counted unconditionally', () {
      expect(fillers('um uh erm er hmm'), 5);
    });
  });

  group('a locale with no lexicon reports "not measured", not zero', () {
    test('fillersMeasured is false and the count is not presented as a score', () {
      final metrics = engine.compute([
        turn(Speaker.user, 'um uh like you know', startSeconds: 0, durationSeconds: 10),
      ], locale: 'ur');

      // The English words are present in the text, and are NOT counted —
      // scoring English hesitation sounds against Urdu speech would be a
      // number that means nothing, presented as if it meant something.
      expect(metrics.fillersMeasured, isFalse);
      expect(metrics.fillerCount, 0);
      expect(metrics.fillerBreakdown, isEmpty);
      // Everything language-independent still works.
      expect(metrics.wordsSpoken, 5);
    });

    test('a regional tag still resolves to its base language', () {
      final metrics = engine.compute([
        turn(Speaker.user, 'um um', startSeconds: 0, durationSeconds: 10),
      ], locale: 'en-GB');
      expect(metrics.fillersMeasured, isTrue);
      expect(metrics.fillerCount, 2);
    });
  });

  group('pace band', () {
    SpeechMetrics paced(int words, int seconds) => engine.compute([
      turn(
        Speaker.user,
        List.filled(words, 'word').join(' '),
        startSeconds: 0,
        durationSeconds: seconds,
      ),
    ], locale: 'en');

    test('too little speech is noData, never "slow"', () {
      // Four words in 1.2s extrapolates to 200wpm. Calling that "fast" — or
      // calling a short quiet answer "slow" — would be a finding invented from
      // arithmetic. R4.3.2 forbids scoring the person; this is the same rule
      // one level down.
      final metrics = paced(4, 2);
      expect(metrics.paceBand, PaceBand.noData);
    });

    test('inside the band is comfortable', () {
      // 60 words in 30s = 120wpm, the lower edge.
      expect(paced(60, 30).paceBand, PaceBand.comfortable);
      // 70 words in 30s = 140wpm.
      expect(paced(70, 30).paceBand, PaceBand.comfortable);
    });

    test('above and below the band are named', () {
      // 100 words in 30s = 200wpm.
      expect(paced(100, 30).paceBand, PaceBand.fast);
      // 30 words in 30s = 60wpm.
      expect(paced(30, 30).paceBand, PaceBand.slow);
    });
  });

  group('vocabulary variety is length-normalised for trends (R4.3.5)', () {
    test('raw TTR falls with length while the normalised one does not', () {
      // The same 10-word vocabulary, repeated. Raw TTR must drop as the text
      // grows; MATTR must not. Charting the raw number across sessions of
      // different lengths would show a user "getting worse" for the sole
      // reason that they spoke for longer.
      const smallWindow = MetricsEngine(varietyWindow: 10);
      final vocabulary = List.generate(10, (i) => 'word$i');

      SpeechMetrics forRepeats(int repeats) => smallWindow.compute([
        turn(
          Speaker.user,
          List.filled(repeats, vocabulary.join(' ')).join(' '),
          startSeconds: 0,
          durationSeconds: 60,
        ),
      ], locale: 'en');

      final short = forRepeats(2);
      final long = forRepeats(10);

      expect(short.vocabularyVariety, greaterThan(long.vocabularyVariety));
      expect(
        short.normalisedVocabularyVariety,
        closeTo(long.normalisedVocabularyVariety, 0.0001),
      );
    });

    test('a session shorter than one window reports zero rather than a guess', () {
      final metrics = engine.compute([
        turn(Speaker.user, 'three words only', startSeconds: 0, durationSeconds: 5),
      ], locale: 'en');
      expect(metrics.normalisedVocabularyVariety, 0);
      // The raw ratio is still honest for a single session.
      expect(metrics.vocabularyVariety, 1.0);
    });
  });

  group('degenerate sessions still produce a report (R4.2.6)', () {
    test('no turns at all', () {
      final metrics = engine.compute([], locale: 'en');
      expect(metrics, same(SpeechMetrics.empty));
      expect(metrics.talkTimeRatio, 0);
      expect(metrics.fillersPerMinute, 0);
    });

    test('no turns but a real duration — the user opened it and said nothing', () {
      final metrics = engine.compute(
        [],
        locale: 'en',
        sessionDuration: const Duration(seconds: 90),
      );
      expect(metrics.duration, const Duration(seconds: 90));
      expect(metrics.wordsSpoken, 0);
      expect(metrics.paceBand, PaceBand.noData);
    });

    test('the partner spoke and the user did not', () {
      final metrics = engine.compute([
        turn(Speaker.partner, 'Are you there?', startSeconds: 0, durationSeconds: 2),
      ], locale: 'en');
      expect(metrics.talkTimeRatio, 0);
      expect(metrics.wordsPerMinute, 0);
      expect(metrics.paceBand, PaceBand.noData);
      expect(metrics.averageResponseLatency, Duration.zero);
    });

    test('turns arriving out of order are still measured correctly', () {
      // A force-killed session recovered from local storage can come back in
      // insertion order rather than in time order (§9.4, R4.2.6).
      final metrics = engine.compute([
        turn(Speaker.user, 'second', startSeconds: 10, durationSeconds: 2),
        turn(Speaker.partner, 'first', startSeconds: 0, durationSeconds: 5),
      ], locale: 'en');
      expect(metrics.averageResponseLatency, const Duration(seconds: 5));
      expect(metrics.bargeInCount, 0);
    });
  });

  group('serialisation to sessions.metrics (§9.5)', () {
    test('survives a round trip intact', () {
      final original = engine.compute([
        turn(Speaker.partner, 'Go ahead.', startSeconds: 0, durationSeconds: 2),
        turn(
          Speaker.user,
          'Um, I would like to talk about, like, the migration we did last year '
          'and what actually went wrong with it in the end',
          startSeconds: 3,
          durationSeconds: 12,
        ),
      ], locale: 'en');

      final restored = SpeechMetrics.fromJson(original.toJson());

      expect(restored.duration, original.duration);
      expect(restored.userSpeakingTime, original.userSpeakingTime);
      expect(restored.partnerSpeakingTime, original.partnerSpeakingTime);
      expect(restored.wordsSpoken, original.wordsSpoken);
      expect(restored.uniqueWords, original.uniqueWords);
      expect(restored.wordsPerMinute, closeTo(original.wordsPerMinute, 0.0001));
      expect(restored.paceBand, original.paceBand);
      expect(restored.fillerCount, original.fillerCount);
      expect(restored.fillerBreakdown, original.fillerBreakdown);
      expect(restored.fillersMeasured, original.fillersMeasured);
      expect(restored.longestUnbrokenStretch, original.longestUnbrokenStretch);
      expect(restored.bargeInCount, original.bargeInCount);
      expect(restored.averageResponseLatency, original.averageResponseLatency);
    });

    test('an unknown pace band decodes to noData rather than throwing', () {
      // Forward compatibility: a row written by a later version must not crash
      // an older client reading its own history offline.
      final restored = SpeechMetrics.fromJson({'pace_band': 'blistering'});
      expect(restored.paceBand, PaceBand.noData);
    });
  });

  group('the engine has no Flutter, storage, or network dependency (D2)', () {
    test('its imports stay pure Dart', () {
      // D2's mitigation is that Drill Mode can consume this engine in
      // Milestone 5 without dragging Sessions in with it. An import of
      // material.dart, drift, or supabase here would break that quietly, and
      // it would only be noticed when Drill Mode was already late.
      const sources = [
        'lib/core/speech_metrics/metrics_engine.dart',
        'lib/core/speech_metrics/speech_metrics.dart',
        'lib/core/speech_metrics/transcript.dart',
        'lib/core/speech_metrics/filler_lexicon.dart',
        'lib/core/speech_metrics/pace_band.dart',
      ];
      const forbidden = [
        'package:flutter/',
        'package:flutter_riverpod/',
        'package:drift/',
        'package:supabase',
        'package:http/',
        'dart:io',
        'dart:ui',
      ];

      final offenders = <String>[];
      for (final path in sources) {
        final source = File(path).readAsStringSync();
        for (final banned in forbidden) {
          if (source.contains("import '$banned")) {
            offenders.add('$path imports $banned');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
