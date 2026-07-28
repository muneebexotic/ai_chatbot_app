import 'package:speakwise/core/speech_metrics/pace_band.dart';

/// Everything R4.3.1 requires, computed on the device with no model call.
///
/// R4.3.1's opening clause is the reason this type exists in the shape it does:
/// "Computed locally, no model call needed (so it works even if the API is
/// down, and so free users get real value)". R8.0.1 goes further — the locally
/// computed report "MUST be genuinely complete, not a teaser". So nothing here
/// is gated, blurred, or withheld; §8's free/Pro split is about the *model
/// generated* coaching in R4.3.2, the trends, and the history depth.
///
/// Immutable, and serialisable to the `sessions.metrics` jsonb column (§9.5).
class SpeechMetrics {
  const SpeechMetrics({
    required this.duration,
    required this.userSpeakingTime,
    required this.partnerSpeakingTime,
    required this.wordsSpoken,
    required this.uniqueWords,
    required this.wordsPerMinute,
    required this.paceBand,
    required this.fillerCount,
    required this.fillerBreakdown,
    required this.fillersMeasured,
    required this.longestUnbrokenStretch,
    required this.vocabularyVariety,
    required this.normalisedVocabularyVariety,
    required this.averageResponseLatency,
    required this.userTurnCount,
    required this.bargeInCount,
  });

  /// Wall-clock length of the session.
  final Duration duration;

  /// How long the user's microphone was actually producing speech.
  final Duration userSpeakingTime;

  /// How long text-to-speech spoke. Shortened by every barge-in (R4.2.3).
  final Duration partnerSpeakingTime;

  /// The user's share of the speaking time, `0.0..1.0`.
  ///
  /// Returns 0 when nobody spoke at all rather than dividing by zero. A session
  /// where the user said nothing is a real outcome — they opened it and got
  /// interrupted — and it must produce a report rather than an exception
  /// (R4.2.6).
  double get talkTimeRatio {
    final total = userSpeakingTime + partnerSpeakingTime;
    return total == Duration.zero
        ? 0
        : userSpeakingTime.inMilliseconds / total.inMilliseconds;
  }

  /// Words the user spoke.
  final int wordsSpoken;

  /// Distinct words the user spoke, case-folded.
  final int uniqueWords;

  /// Speaking pace over [userSpeakingTime], not over [duration].
  ///
  /// Dividing by session length would punish a user for listening, which is
  /// half of a conversation and not a fault.
  final double wordsPerMinute;

  /// Where [wordsPerMinute] falls against the healthy band (R4.3.1).
  final PaceBand paceBand;

  /// Total fillers, and the per-filler breakdown R4.3.1 asks for.
  final int fillerCount;
  final Map<String, int> fillerBreakdown;

  /// False when the app has no filler lexicon for the session's locale.
  ///
  /// Load-bearing: [fillerCount] is then 0, and 0 means "not measured", not
  /// "you used none". The UI must say which. Reporting an unmeasured zero as an
  /// achievement would be an invented fact about the user's performance.
  final bool fillersMeasured;

  /// The longest single unbroken run of user speech.
  final Duration longestUnbrokenStretch;

  /// Type-token ratio: unique words over total words, `0.0..1.0`.
  ///
  /// **This falls as a session gets longer**, for every speaker, because common
  /// words repeat. It is the metric R4.3.1 names, so it is reported — but see
  /// [normalisedVocabularyVariety] before charting it.
  final double vocabularyVariety;

  /// Length-normalised vocabulary variety (moving-average TTR).
  ///
  /// R4.3.5 charts vocabulary variety "over the last 30 sessions". Charting raw
  /// [vocabularyVariety] across sessions of different lengths would show a user
  /// getting worse for the sole reason that they spoke for longer, and the
  /// whole point of the trend is to be actionable. This averages the ratio over
  /// a fixed window of words instead, so two sessions are comparable.
  ///
  /// Zero when the session is shorter than one window; the trend simply has no
  /// point for that session, which is honest.
  final double normalisedVocabularyVariety;

  /// Mean gap between the partner finishing and the user starting to answer.
  ///
  /// A metric about the *user's* fluency, not about the app's speed — R4.2.4's
  /// sub-1.5s budget is the other direction and is an engineering measurement,
  /// not something reported on a card.
  ///
  /// Barge-ins are excluded rather than counted as a negative latency; they are
  /// in [bargeInCount].
  final Duration averageResponseLatency;

  final int userTurnCount;

  /// How often the user started speaking before the partner had finished.
  ///
  /// Not a fault. In interview and debate practice it is a sign of confidence,
  /// and R4.3.2 forbids scoring the person — so this is a fact, presented
  /// without a verdict.
  final int bargeInCount;

  double get fillersPerMinute {
    final minutes = userSpeakingTime.inMilliseconds / 60000;
    return minutes <= 0 ? 0 : fillerCount / minutes;
  }

  /// An empty result, for a session with nothing in it.
  static const empty = SpeechMetrics(
    duration: Duration.zero,
    userSpeakingTime: Duration.zero,
    partnerSpeakingTime: Duration.zero,
    wordsSpoken: 0,
    uniqueWords: 0,
    wordsPerMinute: 0,
    paceBand: PaceBand.noData,
    fillerCount: 0,
    fillerBreakdown: {},
    fillersMeasured: false,
    longestUnbrokenStretch: Duration.zero,
    vocabularyVariety: 0,
    normalisedVocabularyVariety: 0,
    averageResponseLatency: Duration.zero,
    userTurnCount: 0,
    bargeInCount: 0,
  );

  /// For `sessions.metrics` (§9.5).
  ///
  /// Durations are stored as milliseconds rather than as ISO strings so the
  /// column can be aggregated in SQL when R4.3.5's trends need it.
  Map<String, dynamic> toJson() => {
    'duration_ms': duration.inMilliseconds,
    'user_speaking_ms': userSpeakingTime.inMilliseconds,
    'partner_speaking_ms': partnerSpeakingTime.inMilliseconds,
    'words_spoken': wordsSpoken,
    'unique_words': uniqueWords,
    'words_per_minute': wordsPerMinute,
    'pace_band': paceBand.name,
    'filler_count': fillerCount,
    'filler_breakdown': fillerBreakdown,
    'fillers_measured': fillersMeasured,
    'longest_unbroken_ms': longestUnbrokenStretch.inMilliseconds,
    'vocabulary_variety': vocabularyVariety,
    'normalised_vocabulary_variety': normalisedVocabularyVariety,
    'average_response_latency_ms': averageResponseLatency.inMilliseconds,
    'user_turn_count': userTurnCount,
    'barge_in_count': bargeInCount,
  };

  factory SpeechMetrics.fromJson(Map<String, dynamic> json) {
    Duration ms(String key) =>
        Duration(milliseconds: (json[key] as num?)?.toInt() ?? 0);

    return SpeechMetrics(
      duration: ms('duration_ms'),
      userSpeakingTime: ms('user_speaking_ms'),
      partnerSpeakingTime: ms('partner_speaking_ms'),
      wordsSpoken: (json['words_spoken'] as num?)?.toInt() ?? 0,
      uniqueWords: (json['unique_words'] as num?)?.toInt() ?? 0,
      wordsPerMinute: (json['words_per_minute'] as num?)?.toDouble() ?? 0,
      paceBand: PaceBand.values.asNameMap()[json['pace_band']] ?? PaceBand.noData,
      fillerCount: (json['filler_count'] as num?)?.toInt() ?? 0,
      fillerBreakdown:
          (json['filler_breakdown'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ??
          const {},
      fillersMeasured: json['fillers_measured'] as bool? ?? false,
      longestUnbrokenStretch: ms('longest_unbroken_ms'),
      vocabularyVariety: (json['vocabulary_variety'] as num?)?.toDouble() ?? 0,
      normalisedVocabularyVariety:
          (json['normalised_vocabulary_variety'] as num?)?.toDouble() ?? 0,
      averageResponseLatency: ms('average_response_latency_ms'),
      userTurnCount: (json['user_turn_count'] as num?)?.toInt() ?? 0,
      bargeInCount: (json['barge_in_count'] as num?)?.toInt() ?? 0,
    );
  }
}
