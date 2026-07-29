import 'package:speakwise/core/speech_metrics/speech_metrics.dart';

/// One session, as the app stores and lists it (§9.5, §9.4).
///
/// Immutable, per §9.1. Carries both ids because a session exists locally
/// before the server has heard of it — see `SessionRepository`.
class SessionRecord {
  const SessionRecord({
    required this.localId,
    required this.partnerId,
    required this.partnerName,
    required this.startedAt,
    this.serverId,
    this.threadId,
    this.goal,
    this.endedAt,
    this.duration,
    this.metrics,
    this.isSynced = false,
    this.locale = 'en',
  });

  final String localId;

  /// `sessions.id`, once the server has issued one. Null for a session that
  /// has only ever been offline.
  final String? serverId;

  final String partnerId;
  final String partnerName;
  final String? threadId;

  /// R4.1.3's one-line goal.
  final String? goal;

  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration? duration;

  /// R4.3.1, computed on the device. Null while the session is still running,
  /// and also when a stored blob could not be read.
  final SpeechMetrics? metrics;

  /// Whether the close reached the server.
  final bool isSynced;

  /// The locale the metrics were computed under.
  final String locale;

  /// True for a session whose app was killed while it was open (R4.2.6).
  ///
  /// It still has every finalised turn, so it is recoverable rather than lost —
  /// which is the distinction the requirement turns on.
  bool get wasInterrupted => endedAt == null;

  SessionRecord copyWith({
    String? serverId,
    String? threadId,
    DateTime? endedAt,
    Duration? duration,
    SpeechMetrics? metrics,
    bool? isSynced,
  }) => SessionRecord(
    localId: localId,
    serverId: serverId ?? this.serverId,
    partnerId: partnerId,
    partnerName: partnerName,
    threadId: threadId ?? this.threadId,
    goal: goal,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    duration: duration ?? this.duration,
    metrics: metrics ?? this.metrics,
    isSynced: isSynced ?? this.isSynced,
    locale: locale,
  );
}
