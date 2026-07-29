import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/core/speech_metrics/speech_metrics.dart';
import 'package:speakwise/core/speech_metrics/transcript.dart';
import 'package:speakwise/features/session/data/local/session_database.dart';
import 'package:speakwise/features/session/domain/session_record.dart';

/// The local store for sessions and transcripts (PRD §9.4, R4.2.6, R11.5).
///
/// ## The one rule this file exists to keep
///
/// **A turn is on disk before it is on screen.** R4.2.6 requires a force-killed
/// session to still produce a report from what was persisted, and a force-kill
/// gives no warning — no `dispose`, no flush, no final request. Whatever is
/// written at that instant is the entire transcript.
///
/// So [appendTurn] is awaited by the controller before the turn is added to the
/// visible state. The cost is one small local insert per turn, which is
/// invisible next to the model round trip that follows it; the benefit is that
/// the user can never see a line the report will not have.
class SessionRepository {
  SessionRepository(this._db);

  final SessionDatabase _db;

  /// Starts a local session row. Called before anything touches the network.
  ///
  /// The server may be slow, may refuse on quota, or may be unreachable, and in
  /// all three cases the user is already talking. A session that only exists
  /// once the server agrees is a session that loses its first turns.
  Future<Result<void>> createSession(SessionRecord record) async {
    try {
      await _db.into(_db.localSessions).insert(
        LocalSessionsCompanion.insert(
          id: record.localId,
          serverId: Value(record.serverId),
          partnerId: record.partnerId,
          partnerName: record.partnerName,
          threadId: Value(record.threadId),
          goal: Value(record.goal),
          startedAt: record.startedAt,
          locale: Value(record.locale),
        ),
      );
      return const Ok(null);
    } on Object catch (error, stack) {
      Log.w('sessions: createSession failed', error: error);
      return Err(StorageFailure(cause: error, stackTrace: stack));
    }
  }

  /// Records the ids the server assigned, once it has.
  Future<void> attachServerIds(
    String localId, {
    String? serverId,
    String? threadId,
  }) async {
    try {
      await (_db.update(_db.localSessions)..where((t) => t.id.equals(localId)))
          .write(
            LocalSessionsCompanion(
              serverId: serverId == null ? const Value.absent() : Value(serverId),
              threadId: threadId == null ? const Value.absent() : Value(threadId),
            ),
          );
    } on Object catch (error) {
      // Not fatal. The transcript is what matters; a missing server id costs a
      // sync, not the user's words.
      Log.w('sessions: attachServerIds failed', error: error);
    }
  }

  /// Appends one finalised turn.
  ///
  /// Awaited before the turn is shown. See the class comment.
  Future<Result<void>> appendTurn(String localSessionId, TranscriptTurn turn, {
    double confidence = 1,
  }) async {
    try {
      await _db.into(_db.localTurns).insert(
        LocalTurnsCompanion.insert(
          sessionId: localSessionId,
          speaker: turn.speaker.name,
          content: turn.text,
          startOffsetMs: turn.startOffset.inMilliseconds,
          durationMs: turn.duration.inMilliseconds,
          confidence: Value(confidence),
        ),
      );
      return const Ok(null);
    } on Object catch (error, stack) {
      Log.w('sessions: appendTurn failed', error: error);
      return Err(StorageFailure(cause: error, stackTrace: stack));
    }
  }

  /// Closes a session locally with its computed metrics.
  Future<Result<void>> closeSession(
    String localId, {
    required Duration duration,
    required SpeechMetrics metrics,
    bool synced = false,
  }) async {
    try {
      await (_db.update(_db.localSessions)..where((t) => t.id.equals(localId)))
          .write(
            LocalSessionsCompanion(
              endedAt: Value(DateTime.now()),
              durationSeconds: Value(duration.inSeconds),
              metricsJson: Value(jsonEncode(metrics.toJson())),
              isSynced: Value(synced),
            ),
          );
      return const Ok(null);
    } on Object catch (error, stack) {
      Log.w('sessions: closeSession failed', error: error);
      return Err(StorageFailure(cause: error, stackTrace: stack));
    }
  }

  Future<void> markSynced(String localId) async {
    try {
      await (_db.update(_db.localSessions)..where((t) => t.id.equals(localId)))
          .write(const LocalSessionsCompanion(isSynced: Value(true)));
    } on Object catch (error) {
      Log.w('sessions: markSynced failed', error: error);
    }
  }

  /// The transcript of one session, in time order.
  Future<List<TranscriptTurn>> turns(String localSessionId) async {
    final rows =
        await (_db.select(_db.localTurns)
              ..where((t) => t.sessionId.equals(localSessionId))
              ..orderBy([(t) => OrderingTerm(expression: t.startOffsetMs)]))
            .get();

    return [
      for (final row in rows)
        TranscriptTurn(
          // Unknown speaker values decode as partner rather than throwing. A
          // row written by a future build must not make an old build unable to
          // open its own history.
          speaker: row.speaker == Speaker.user.name
              ? Speaker.user
              : Speaker.partner,
          text: row.content,
          startOffset: Duration(milliseconds: row.startOffsetMs),
          duration: Duration(milliseconds: row.durationMs),
        ),
    ];
  }

  /// Sessions that never reached a clean close — R4.2.6's force-kill recovery.
  ///
  /// A row with no `endedAt` is one whose app died while it was open. It still
  /// has every turn that had been finalised, which is exactly what the
  /// requirement asks to be recoverable.
  Future<List<SessionRecord>> unfinished() async {
    final rows = await (_db.select(_db.localSessions)
          ..where((t) => t.endedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.startedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
    return rows.map(_toRecord).toList();
  }

  /// Closed sessions that have not reached the server (R11.5's queue).
  Future<List<SessionRecord>> pendingSync() async {
    final rows = await (_db.select(_db.localSessions)
          ..where((t) => t.endedAt.isNotNull() & t.isSynced.equals(false)))
        .get();
    return rows.map(_toRecord).toList();
  }

  /// Local history, newest first. Works with no network at all (R11.5).
  Future<List<SessionRecord>> history({int limit = 30}) async {
    final rows = await (_db.select(_db.localSessions)
          ..where((t) => t.endedAt.isNotNull())
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.startedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .get();
    return rows.map(_toRecord).toList();
  }

  Future<SessionRecord?> byLocalId(String localId) async {
    final row = await (_db.select(_db.localSessions)
          ..where((t) => t.id.equals(localId)))
        .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  SessionRecord _toRecord(LocalSessionRow row) => SessionRecord(
    localId: row.id,
    serverId: row.serverId,
    partnerId: row.partnerId,
    partnerName: row.partnerName,
    threadId: row.threadId,
    goal: row.goal,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    duration: row.durationSeconds == null
        ? null
        : Duration(seconds: row.durationSeconds!),
    metrics: _decodeMetrics(row.metricsJson),
    isSynced: row.isSynced,
    locale: row.locale,
  );

  /// Never throws on a bad row.
  ///
  /// A metrics blob that cannot be parsed — written by a different version,
  /// truncated by a disk-full — must degrade to "this session has no metrics"
  /// rather than making the whole history screen fail to load. Losing one
  /// number is a smaller loss than losing the list.
  SpeechMetrics? _decodeMetrics(String? json) {
    if (json == null) return null;
    try {
      return SpeechMetrics.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } on Object catch (error) {
      Log.w('sessions: unreadable metrics blob', error: error);
      return null;
    }
  }
}
