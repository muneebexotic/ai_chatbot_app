import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'session_database.g.dart';

/// Local persistence for sessions and their transcripts — PRD §9.4, R4.2.6.
///
/// ## Why this exists rather than "we upload the turn and move on"
///
/// R4.2.6: "A session that is force-killed MUST still produce a report from
/// whatever transcript was persisted."
///
/// A force-kill is not a graceful shutdown. There is no `dispose`, no final
/// flush, no chance to POST anything. Whatever is on disk at that instant is
/// the whole transcript, so every finalised turn is written here **before it is
/// rendered** — the user cannot see a line that is not already saved.
///
/// §9.4 names Drift for "threads, messages, sessions, and reports, so history
/// and past reports work fully offline", and R11.5 requires a session started
/// offline to record its transcript locally and compute R4.3.1's metrics with
/// no network at all. Both need a real local database rather than a cache.
///
/// ## Why the local id is not the server id
///
/// A session exists on the device before the server has heard of it: the user
/// taps Start, and `open_voice_session` may be slow, may be refused on quota,
/// or may be unreachable. Turns can already be accumulating. So a session gets
/// a local id immediately and records the server's separately when it arrives,
/// which is also what lets an offline session sync later without rewriting
/// every row that points at it.
@DataClassName('LocalSessionRow')
class LocalSessions extends Table {
  /// Client-generated, assigned before anything touches the network.
  TextColumn get id => text()();

  /// `sessions.id` on the server, once `open_voice_session` has returned one.
  /// Null for a session that has never been online.
  TextColumn get serverId => text().nullable()();

  TextColumn get partnerId => text()();

  /// Denormalised on purpose. A report opened offline has to name its partner,
  /// and `partners` lives in Postgres — R11.5 says full history works offline,
  /// which a foreign key to a remote table cannot deliver.
  TextColumn get partnerName => text()();

  TextColumn get threadId => text().nullable()();
  TextColumn get goal => text().nullable()();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  /// `SpeechMetrics.toJson`, computed on the device (R4.3.1).
  TextColumn get metricsJson => text().nullable()();

  /// Whether the closing call reached the server. False after a force-kill and
  /// after any offline session; the next launch retries.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Which filler lexicon the metrics were computed against, so a recomputation
  /// later cannot silently score English rules against another language.
  TextColumn get locale => text().withDefault(const Constant('en'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One line of transcript.
///
/// Append-only. A turn is written when it is final and is never edited, which
/// is what makes "whatever was persisted" a coherent thing to recover: there is
/// no half-written row to reason about, only a shorter list than the user
/// remembers.
@DataClassName('LocalTurnRow')
class LocalTurns extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get sessionId => text().references(LocalSessions, #id)();

  /// 'user' or 'partner', matching `Speaker` in the metrics engine.
  ///
  /// Stored as text rather than an index: an enum's ordinal changes the moment
  /// somebody inserts a value, and this row may be read by a build that is
  /// months older than the one that wrote it.
  TextColumn get speaker => text()();

  TextColumn get content => text()();

  /// From the start of the session, so `TranscriptTurn` reconstructs exactly.
  IntColumn get startOffsetMs => integer()();
  IntColumn get durationMs => integer()();

  /// The recogniser's confidence for a user turn (R4.2.5 lets the user tap a
  /// line to see what was heard; a low number here is why they would).
  RealColumn get confidence => real().withDefault(const Constant(1))();
}

@DriftDatabase(tables: [LocalSessions, LocalTurns])
class SessionDatabase extends _$SessionDatabase {
  SessionDatabase() : super(_open());

  /// For tests: an in-memory database with the same schema.
  SessionDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() {
    return LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, 'speakwise_sessions.sqlite'));

      // Works around a set of old Android SQLite builds that reject
      // `LazyDatabase`'s temp-file handling. Costs one call at startup and
      // removes a class of "only on some phones" failure — §16 forbids a
      // feature that only works on a fast phone, and the same reasoning
      // applies to only working on a recent one.
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

      return NativeDatabase.createInBackground(file);
    });
  }
}
