import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/safety/crisis_detector.dart';
import 'package:speakwise/core/speech_metrics/speech_metrics.dart';
import 'package:speakwise/core/speech_metrics/transcript.dart';
import 'package:speakwise/features/session/domain/session_settings.dart';

/// What the live session screen is doing right now (PRD R4.2.1).
///
/// R4.2.1 requires the screen to show "partner name and state (listening /
/// thinking / speaking)". These are those states, plus the two the requirement
/// implies but does not name: a session has to start, and R4.2.6 requires it to
/// pause.
enum SessionPhase {
  /// Permissions, recogniser binding, the server's `open`. Brief, and the one
  /// place a session can fail before it has begun.
  starting,

  /// The microphone is open. The only phase that paints `live` red (R7.1.1).
  listening,

  /// The user's turn is finished and the model has not produced a first
  /// sentence yet. This is the phase R4.2.4's 1.5s budget is measured across.
  thinking,

  /// Text-to-speech is talking. Barge-in (R4.2.3) applies here and nowhere
  /// else.
  speaking,

  /// R4.2.6: a phone call, a backgrounding, headphones out, or the network
  /// dropping. Recoverable by construction — nothing is lost.
  paused,

  ended,
}

/// Why a session paused (R4.2.6).
///
/// Named rather than boolean because §7.6 requires an error to state its cause
/// and its fix, and "your headphones came out" and "you have no network" have
/// nothing in common as fixes.
enum InterruptionReason {
  incomingCall,
  backgrounded,
  headphonesDisconnected,
  networkLost,
  microphoneLost,
}

/// One line of the live transcript (R4.2.5).
class SessionTurn {
  const SessionTurn({
    required this.id,
    required this.speaker,
    required this.text,
    required this.startOffset,
    required this.duration,
    this.confidence = 1,
  });

  final String id;
  final Speaker speaker;
  final String text;
  final Duration startOffset;
  final Duration duration;

  /// The recogniser's confidence, for user turns. R4.2.5: "tapping any user
  /// line shows what the recognizer heard" — this is how the UI knows when to
  /// say it heard poorly.
  final double confidence;

  /// The metrics engine's input type.
  ///
  /// A deliberate conversion rather than making the engine take this class:
  /// DECISIONS D2 requires the engine to be usable by Drill Mode without
  /// dragging Sessions in, and a `SessionTurn` is a Sessions type.
  TranscriptTurn toTranscriptTurn() => TranscriptTurn(
    speaker: speaker,
    text: text,
    startOffset: startOffset,
    duration: duration,
  );
}

/// Everything the live session screen renders from.
class SessionState {
  const SessionState({
    this.phase = SessionPhase.starting,
    this.turns = const [],
    this.partialText = '',
    this.elapsed = Duration.zero,
    this.inputMode = SessionInputMode.handsFree,
    this.isMuted = false,
    this.usage,
    this.failure,
    this.interruption,
    this.crisis,
    this.isEnvironmentNoisy = false,
    this.hasSuggestedPushToTalk = false,
    this.isTypingFallback = false,
    this.turnLatencies = const [],
    this.metrics,
    this.localId,
    this.serverSessionId,
    this.partnerName = '',
  });

  final SessionPhase phase;

  /// Finalised turns only. A turn appears here after it has been written to
  /// local storage (§9.4), never before — R4.2.6's force-kill guarantee is
  /// only true if the user cannot see a line the report will not have.
  final List<SessionTurn> turns;

  /// The in-progress recognition, shown live and not yet a turn.
  final String partialText;

  final Duration elapsed;
  final SessionInputMode inputMode;
  final bool isMuted;

  /// Quota as the SERVER reported it (F2). The client renders this number and
  /// never computes one.
  final SessionUsage? usage;

  final AppFailure? failure;
  final InterruptionReason? interruption;

  /// R10.6. Once set it is never cleared for the life of the session: the card
  /// is "persistent" in the requirement's own word, and a card the user can
  /// dismiss by continuing to talk is not persistent.
  final CrisisMatch? crisis;

  /// R4.2.2's noisy-environment detection.
  final bool isEnvironmentNoisy;

  /// Whether the push-to-talk suggestion has already been offered. Offered
  /// once per session: R4.2.2 says "non-blocking suggestion, never a forced
  /// switch", and a suggestion that returns every five seconds is neither.
  final bool hasSuggestedPushToTalk;

  /// PROPOSALS P8, approved for this milestone: keep the session, switch to
  /// typing, keep the transcript and the report intact.
  final bool isTypingFallback;

  /// R4.2.4 / §14: end-of-speech to first spoken word, one entry per turn.
  /// §14 asks for the median over 20 turns, which is computed from this.
  final List<Duration> turnLatencies;

  /// Computed at the end, on the device (R4.3.1).
  final SpeechMetrics? metrics;

  final String? localId;
  final String? serverSessionId;
  final String partnerName;

  bool get isLive =>
      phase == SessionPhase.listening ||
      phase == SessionPhase.thinking ||
      phase == SessionPhase.speaking;

  /// The median of [turnLatencies] — §14's measurement.
  ///
  /// Median rather than mean because one 8-second outlier from a stalled
  /// request would move a mean past the budget while every real turn was
  /// inside it, and because §14 asks for the median by name.
  Duration? get medianLatency {
    if (turnLatencies.isEmpty) return null;
    final sorted = [...turnLatencies]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return Duration(
      milliseconds:
          (sorted[middle - 1].inMilliseconds + sorted[middle].inMilliseconds) ~/ 2,
    );
  }

  SessionState copyWith({
    SessionPhase? phase,
    List<SessionTurn>? turns,
    String? partialText,
    Duration? elapsed,
    SessionInputMode? inputMode,
    bool? isMuted,
    SessionUsage? usage,
    AppFailure? failure,
    bool clearFailure = false,
    InterruptionReason? interruption,
    bool clearInterruption = false,
    CrisisMatch? crisis,
    bool? isEnvironmentNoisy,
    bool? hasSuggestedPushToTalk,
    bool? isTypingFallback,
    List<Duration>? turnLatencies,
    SpeechMetrics? metrics,
    String? localId,
    String? serverSessionId,
    String? partnerName,
  }) => SessionState(
    phase: phase ?? this.phase,
    turns: turns ?? this.turns,
    partialText: partialText ?? this.partialText,
    elapsed: elapsed ?? this.elapsed,
    inputMode: inputMode ?? this.inputMode,
    isMuted: isMuted ?? this.isMuted,
    usage: usage ?? this.usage,
    failure: clearFailure ? null : (failure ?? this.failure),
    interruption: clearInterruption ? null : (interruption ?? this.interruption),
    // Never cleared. See the field comment: R10.6 says persistent.
    crisis: crisis ?? this.crisis,
    isEnvironmentNoisy: isEnvironmentNoisy ?? this.isEnvironmentNoisy,
    hasSuggestedPushToTalk:
        hasSuggestedPushToTalk ?? this.hasSuggestedPushToTalk,
    isTypingFallback: isTypingFallback ?? this.isTypingFallback,
    turnLatencies: turnLatencies ?? this.turnLatencies,
    metrics: metrics ?? this.metrics,
    localId: localId ?? this.localId,
    serverSessionId: serverSessionId ?? this.serverSessionId,
    partnerName: partnerName ?? this.partnerName,
  );
}

/// The server's account of the user's spoken allowance (§8, F2).
class SessionUsage {
  const SessionUsage({
    required this.tier,
    required this.usedSeconds,
    required this.dailyLimitSeconds,
    required this.remainingSeconds,
    this.resetsAt,
    this.isUpgradeable = true,
  });

  factory SessionUsage.fromJson(Map<String, dynamic> json) => SessionUsage(
    tier: json['tier'] as String? ?? 'free',
    usedSeconds: (json['usedSeconds'] as num?)?.toInt() ?? 0,
    dailyLimitSeconds: (json['dailyLimitSeconds'] as num?)?.toInt() ?? 0,
    remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
    resetsAt: switch (json['resetsAt']) {
      final String s => DateTime.tryParse(s)?.toLocal(),
      _ => null,
    },
    isUpgradeable: json['upgradeable'] as bool? ?? true,
  );

  final String tier;
  final int usedSeconds;
  final int dailyLimitSeconds;
  final int remainingSeconds;
  final DateTime? resetsAt;
  final bool isUpgradeable;

  Duration get remaining => Duration(seconds: remainingSeconds);

  /// Whether to warn. Two minutes, and not before.
  ///
  /// §16 bans manufactured scarcity, and a countdown visible from the first
  /// second turns every sentence into a transaction. R8.3 puts the paywall at
  /// "the moment of maximum felt value", which is the end of a good session,
  /// not the start of one.
  bool get shouldWarn => remainingSeconds > 0 && remainingSeconds <= 120;

  bool get isExhausted => remainingSeconds <= 0;
}
