import 'package:speakwise/core/speech_metrics/filler_lexicon.dart';
import 'package:speakwise/core/speech_metrics/pace_band.dart';
import 'package:speakwise/core/speech_metrics/speech_metrics.dart';
import 'package:speakwise/core/speech_metrics/transcript.dart';

/// R4.3.1, in full, as a pure function.
///
/// ## Why this module is standalone
///
/// DECISIONS D2 moved the free tier to Drill Mode and made this engine its
/// scoring layer, then recorded the risk plainly: "Drill Mode is launch-critical
/// but scheduled last, at Milestone 5, because it depends on the R4.3.1 metrics
/// engine from Milestone 4. Mitigation: build that engine as a standalone,
/// independently testable module with Drill Mode as a known consumer, and treat
/// a Milestone 4 slip as a threat to launch rather than to one milestone."
///
/// So: no Flutter import, no Riverpod, no database type, no `BuildContext`, no
/// network, and no user-facing string. It takes turns and returns numbers. A
/// Session builds the turns from live speech; Drill Mode will build them from a
/// drill attempt; the tests build them from literals. If this file ever needs a
/// Session to run, D2's mitigation has quietly failed.
///
/// ## Why every number is computed here rather than in the UI
///
/// R4.3.1 says these must work "even if the API is down", and R11.5 requires an
/// offline session to compute them locally. A metric derived in a widget is a
/// metric that cannot be recomputed from a stored transcript, cannot be tested
/// without pumping a tree, and cannot be reused by Drill Mode.
class MetricsEngine {
  const MetricsEngine({
    this.paceBand = SpeechPaceBand.conversational,
    this.varietyWindow = 50,
  });

  final SpeechPaceBand paceBand;

  /// Window size, in words, for [SpeechMetrics.normalisedVocabularyVariety].
  ///
  /// 50 is short enough that a two-minute session produces one, and long enough
  /// that the ratio is not dominated by a single sentence.
  final int varietyWindow;

  /// Splits text into comparable word tokens.
  ///
  /// Keeps internal apostrophes so "don't" is one word rather than two, and
  /// keeps internal hyphens so "well-known" is not double counted. Everything
  /// else that is not a letter or a digit is a separator. Case-folded, because
  /// "The" and "the" are the same word for every metric here.
  ///
  /// Exposed rather than private so the tests can pin the tokenizer directly —
  /// every count in this file rests on it, so a silent change to it is a silent
  /// change to all of them.
  static List<String> tokenize(String text) {
    final matches = RegExp(
      r"[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*",
      unicode: true,
    ).allMatches(text.toLowerCase());
    return [for (final m in matches) m.group(0)!];
  }

  /// Computes every metric in R4.3.1 from [turns].
  ///
  /// [locale] selects the filler lexicon. [sessionDuration] is the wall-clock
  /// length; when null it is derived from the turns, which is the right answer
  /// for a drill and the wrong one for a session that ended in silence.
  SpeechMetrics compute(
    List<TranscriptTurn> turns, {
    required String locale,
    Duration? sessionDuration,
  }) {
    if (turns.isEmpty) {
      return sessionDuration == null || sessionDuration == Duration.zero
          ? SpeechMetrics.empty
          : _emptyWithDuration(sessionDuration);
    }

    final userTurns = turns.where((t) => t.speaker == Speaker.user).toList();
    final partnerTurns = turns.where((t) => t.speaker == Speaker.partner).toList();

    var userSpeaking = Duration.zero;
    var longest = Duration.zero;
    for (final turn in userTurns) {
      userSpeaking += turn.duration;
      if (turn.duration > longest) longest = turn.duration;
    }

    var partnerSpeaking = Duration.zero;
    for (final turn in partnerTurns) {
      partnerSpeaking += turn.duration;
    }

    // Words, from the user's turns only. The partner's word count is not a
    // measurement of the user and does not appear on the report.
    final words = <String>[];
    for (final turn in userTurns) {
      words.addAll(tokenize(turn.text));
    }

    final speakingMinutes = userSpeaking.inMilliseconds / 60000;
    final wpm = speakingMinutes <= 0 ? 0.0 : words.length / speakingMinutes;

    final lexicon = FillerLexicon.forLocale(locale);
    final breakdown = <String, int>{};
    if (lexicon != null) {
      for (final turn in userTurns) {
        _countFillers(tokenize(turn.text), lexicon, breakdown);
      }
    }
    final fillerCount = breakdown.values.fold(0, (a, b) => a + b);

    final latencies = _responseLatencies(turns);

    return SpeechMetrics(
      duration: sessionDuration ?? _derivedDuration(turns),
      userSpeakingTime: userSpeaking,
      partnerSpeakingTime: partnerSpeaking,
      wordsSpoken: words.length,
      uniqueWords: words.toSet().length,
      wordsPerMinute: wpm,
      paceBand: paceBand.classify(wpm, wordsSpoken: words.length),
      fillerCount: fillerCount,
      // Sorted high to low so the UI does not have to decide what matters; the
      // filler a user says most is the one worth naming first.
      fillerBreakdown: Map.fromEntries(
        breakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      ),
      fillersMeasured: lexicon != null,
      longestUnbrokenStretch: longest,
      vocabularyVariety: words.isEmpty ? 0 : words.toSet().length / words.length,
      normalisedVocabularyVariety: _movingAverageTtr(words),
      averageResponseLatency: latencies.$1,
      userTurnCount: userTurns.length,
      bargeInCount: latencies.$2,
    );
  }

  SpeechMetrics _emptyWithDuration(Duration duration) => SpeechMetrics(
    duration: duration,
    userSpeakingTime: Duration.zero,
    partnerSpeakingTime: Duration.zero,
    wordsSpoken: 0,
    uniqueWords: 0,
    wordsPerMinute: 0,
    paceBand: PaceBand.noData,
    fillerCount: 0,
    fillerBreakdown: const {},
    fillersMeasured: false,
    longestUnbrokenStretch: Duration.zero,
    vocabularyVariety: 0,
    normalisedVocabularyVariety: 0,
    averageResponseLatency: Duration.zero,
    userTurnCount: 0,
    bargeInCount: 0,
  );

  Duration _derivedDuration(List<TranscriptTurn> turns) {
    var end = Duration.zero;
    for (final turn in turns) {
      if (turn.endOffset > end) end = turn.endOffset;
    }
    return end;
  }

  /// Mean answer gap, and the barge-in count.
  ///
  /// Walks the turns in order and looks at every user turn that directly
  /// follows a partner turn. A gap is the gap; a *negative* gap means the user
  /// started before the partner stopped, which is a barge-in (R4.2.3) and not a
  /// latency of minus one second.
  (Duration, int) _responseLatencies(List<TranscriptTurn> turns) {
    final ordered = [...turns]
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    var total = Duration.zero;
    var counted = 0;
    var bargeIns = 0;

    for (var i = 1; i < ordered.length; i++) {
      final current = ordered[i];
      final previous = ordered[i - 1];
      if (current.speaker != Speaker.user) continue;
      if (previous.speaker != Speaker.partner) continue;

      final gap = current.startOffset - previous.endOffset;
      if (gap.isNegative) {
        bargeIns++;
        continue;
      }
      total += gap;
      counted++;
    }

    return (
      counted == 0
          ? Duration.zero
          : Duration(milliseconds: total.inMilliseconds ~/ counted),
      bargeIns,
    );
  }

  /// Moving-average type-token ratio over [varietyWindow] words.
  ///
  /// Plain TTR falls as any text grows, so comparing two sessions of different
  /// lengths on it measures length, not vocabulary. MATTR averages the ratio
  /// over a fixed window, which removes that dependence.
  double _movingAverageTtr(List<String> words) {
    if (words.length < varietyWindow) return 0;

    var total = 0.0;
    var windows = 0;
    for (var start = 0; start + varietyWindow <= words.length; start++) {
      final window = words.sublist(start, start + varietyWindow);
      total += window.toSet().length / varietyWindow;
      windows++;
    }
    return windows == 0 ? 0 : total / windows;
  }

  /// Counts fillers in one turn's tokens, into [into].
  ///
  /// Longest phrase first, so "you know" is counted once as itself rather than
  /// twice as "you" and "know" — and so a matched phrase consumes its tokens
  /// and cannot also be matched by a shorter rule inside it.
  void _countFillers(
    List<String> tokens,
    FillerLexicon lexicon,
    Map<String, int> into,
  ) {
    final rules = [...lexicon.rules]
      ..sort(
        (a, b) => b.phrase.split(' ').length.compareTo(a.phrase.split(' ').length),
      );

    final consumed = List<bool>.filled(tokens.length, false);

    for (final rule in rules) {
      final phrase = rule.phrase.split(' ');
      for (var i = 0; i + phrase.length <= tokens.length; i++) {
        if (consumed.getRange(i, i + phrase.length).any((c) => c)) continue;

        var matches = true;
        for (var j = 0; j < phrase.length; j++) {
          if (tokens[i + j] != phrase[j]) {
            matches = false;
            break;
          }
        }
        if (!matches) continue;

        final before = i > 0 ? tokens[i - 1] : null;
        final after = i + phrase.length < tokens.length
            ? tokens[i + phrase.length]
            : null;

        if (before != null && rule.notPrecededBy.contains(before)) continue;
        if (after != null && rule.notFollowedBy.contains(after)) continue;
        if (rule.clauseInitialOnly &&
            before != null &&
            !clauseOpeners.contains(before)) {
          continue;
        }

        into[rule.phrase] = (into[rule.phrase] ?? 0) + 1;
        for (var j = 0; j < phrase.length; j++) {
          consumed[i + j] = true;
        }
      }
    }
  }
}
