// `show Value` is not tidiness: drift and matcher both export `isNull` and
// `isNotNull`, and an unrestricted import makes every `expect(x, isNull)` in
// this file a compile error about an ambiguous name.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/core/speech_metrics/metrics_engine.dart';
import 'package:speakwise/core/speech_metrics/speech_metrics.dart';
import 'package:speakwise/core/speech_metrics/transcript.dart';
import 'package:speakwise/features/session/data/local/session_database.dart';
import 'package:speakwise/features/session/data/session_repository.dart';
import 'package:speakwise/features/session/domain/session_record.dart';

/// §9.4 local persistence, and R4.2.6's force-kill guarantee.
///
/// "A session that is force-killed MUST still produce a report from whatever
/// transcript was persisted."
///
/// That sentence is only true if two things hold, and both are asserted here:
/// a turn reaches the disk before the user sees it, and a session with no
/// `endedAt` can be found again and fed to the metrics engine. Neither is
/// visible by reading the controller.
void main() {
  late SessionDatabase db;
  late SessionRepository repository;

  setUp(() {
    // In-memory, same schema. No file system, so the suite stays fast and
    // leaves nothing behind.
    db = SessionDatabase.forTesting(NativeDatabase.memory());
    repository = SessionRepository(db);
  });

  tearDown(() => db.close());

  SessionRecord record({String id = 'local-1'}) => SessionRecord(
    localId: id,
    partnerId: '11111111-1111-4111-8111-000000000002',
    partnerName: 'Interviewer',
    startedAt: DateTime(2026, 7, 29, 10),
    goal: 'frontend interview on Tuesday',
  );

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

  group('a session is local before it is remote', () {
    test('it can be created with no server id at all', () async {
      // The user taps Start and begins talking. open_voice_session may be slow,
      // refused on quota, or unreachable — and a session that only exists once
      // the server agrees is a session that loses its first turns.
      expect(await repository.createSession(record()), isA<Ok<void>>());

      final stored = await repository.byLocalId('local-1');
      expect(stored, isNotNull);
      expect(stored!.serverId, isNull);
      expect(stored.partnerName, 'Interviewer');
      expect(stored.goal, 'frontend interview on Tuesday');
    });

    test('server ids are attached later without disturbing the turns', () async {
      await repository.createSession(record());
      await repository.appendTurn(
        'local-1',
        turn(Speaker.user, 'hello', startSeconds: 0, durationSeconds: 2),
      );

      await repository.attachServerIds(
        'local-1',
        serverId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        threadId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );

      final stored = await repository.byLocalId('local-1');
      expect(stored!.serverId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      expect(stored.threadId, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
      expect(await repository.turns('local-1'), hasLength(1));
    });
  });

  group('R4.2.6 — a force-killed session still produces a report', () {
    test('unfinished sessions are found, with every finalised turn', () async {
      await repository.createSession(record());
      await repository.appendTurn(
        'local-1',
        turn(Speaker.partner, 'Tell me about a project.',
            startSeconds: 0, durationSeconds: 3),
      );
      await repository.appendTurn(
        'local-1',
        turn(Speaker.user, 'Um, I built a scheduling tool for my team.',
            startSeconds: 4, durationSeconds: 8),
      );
      // ...and here the process dies. No close, no flush, no final request.

      final unfinished = await repository.unfinished();
      expect(unfinished, hasLength(1));
      expect(unfinished.first.localId, 'local-1');
      expect(
        unfinished.first.wasInterrupted,
        isTrue,
        reason: 'no endedAt is what marks a session the app died inside',
      );

      final turns = await repository.turns('local-1');
      expect(turns, hasLength(2));
      expect(turns.first.speaker, Speaker.partner);
      expect(turns.last.text, contains('scheduling tool'));
    });

    test('the recovered transcript computes real metrics', () async {
      // The whole point of the requirement: not "the data survives" but "a
      // report can still be produced from it". This is that sentence, executed.
      await repository.createSession(record());
      await repository.appendTurn(
        'local-1',
        turn(Speaker.partner, 'Go ahead.', startSeconds: 0, durationSeconds: 2),
      );
      await repository.appendTurn(
        'local-1',
        turn(
          Speaker.user,
          'Um, so I built a, like, scheduling tool for my team. '
          'It actually saved us time.',
          startSeconds: 3,
          durationSeconds: 10,
        ),
      );

      final recovered = await repository.turns('local-1');
      final metrics = const MetricsEngine().compute(recovered, locale: 'en');

      expect(metrics.wordsSpoken, 16);
      expect(metrics.fillerCount, 2);
      expect(metrics.userSpeakingTime, const Duration(seconds: 10));
      expect(metrics.averageResponseLatency, const Duration(seconds: 1));
    });

    test('a closed session is not reported as unfinished', () async {
      await repository.createSession(record());
      await repository.closeSession(
        'local-1',
        duration: const Duration(minutes: 4),
        metrics: SpeechMetrics.empty,
      );

      expect(await repository.unfinished(), isEmpty);
      final stored = await repository.byLocalId('local-1');
      expect(stored!.wasInterrupted, isFalse);
      expect(stored.duration, const Duration(minutes: 4));
    });

    test('turns come back in time order even when inserted out of order', () async {
      // Recovery reads by start offset, not by insertion. A turn finalised late
      // — the partner's, which is written when speech finishes — can be
      // inserted after a user turn that started earlier.
      await repository.createSession(record());
      await repository.appendTurn('local-1',
          turn(Speaker.user, 'second', startSeconds: 10, durationSeconds: 2));
      await repository.appendTurn('local-1',
          turn(Speaker.partner, 'first', startSeconds: 0, durationSeconds: 5));

      final turns = await repository.turns('local-1');
      expect(turns.map((t) => t.text), ['first', 'second']);
    });
  });

  group('metrics survive a round trip through the database', () {
    test('what is stored is what comes back', () async {
      final metrics = const MetricsEngine().compute([
        turn(Speaker.partner, 'Go on.', startSeconds: 0, durationSeconds: 2),
        turn(
          Speaker.user,
          'I would like to talk about the migration, and what actually went '
          'wrong with it in the end',
          startSeconds: 3,
          durationSeconds: 9,
        ),
      ], locale: 'en');

      await repository.createSession(record());
      await repository.closeSession(
        'local-1',
        duration: const Duration(seconds: 12),
        metrics: metrics,
      );

      final stored = (await repository.byLocalId('local-1'))!.metrics!;
      expect(stored.wordsSpoken, metrics.wordsSpoken);
      expect(stored.fillerBreakdown, metrics.fillerBreakdown);
      expect(stored.paceBand, metrics.paceBand);
      expect(stored.wordsPerMinute, closeTo(metrics.wordsPerMinute, 0.0001));
    });

    test('an unreadable metrics blob loses one session, not the list', () async {
      // Written by a different version, or truncated by a full disk. The
      // history screen must still open — losing one number is a smaller loss
      // than losing the list.
      await repository.createSession(record());
      await repository.closeSession(
        'local-1',
        duration: const Duration(seconds: 30),
        metrics: SpeechMetrics.empty,
      );
      await (db.update(db.localSessions)..where((t) => t.id.equals('local-1')))
          .write(const LocalSessionsCompanion(metricsJson: Value('{not json')));

      final history = await repository.history();
      expect(history, hasLength(1));
      expect(history.first.metrics, isNull);
      expect(history.first.duration, const Duration(seconds: 30));
    });
  });

  group('R11.5 — the offline queue', () {
    test('a closed but unsynced session is pending, a synced one is not', () async {
      await repository.createSession(record());
      await repository.closeSession(
        'local-1',
        duration: const Duration(minutes: 2),
        metrics: SpeechMetrics.empty,
      );

      expect(await repository.pendingSync(), hasLength(1));

      await repository.markSynced('local-1');
      expect(await repository.pendingSync(), isEmpty);
    });

    test('an open session is not queued for sync', () async {
      // It is not finished, so there is nothing to send yet. Sending a
      // half-session would produce a report the user never asked for.
      await repository.createSession(record());
      expect(await repository.pendingSync(), isEmpty);
    });

    test('history is newest first and excludes running sessions', () async {
      for (final (index, day) in [3, 1, 2].indexed) {
        await repository.createSession(
          SessionRecord(
            localId: 'local-$index',
            partnerId: 'p',
            partnerName: 'Free Talk',
            startedAt: DateTime(2026, 7, day),
          ),
        );
        await repository.closeSession(
          'local-$index',
          duration: const Duration(minutes: 1),
          metrics: SpeechMetrics.empty,
        );
      }
      await repository.createSession(record(id: 'still-running'));

      final history = await repository.history();
      expect(history.map((s) => s.localId), ['local-0', 'local-2', 'local-1']);
      expect(history.any((s) => s.localId == 'still-running'), isFalse);
    });
  });
}
