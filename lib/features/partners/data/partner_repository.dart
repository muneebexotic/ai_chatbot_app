import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/features/chat/data/chat_repository.dart'
    show mapPostgrestError;
import 'package:speakwise/features/partners/domain/partner.dart';

/// Partners, read as data (PRD §5.3.2).
///
/// "Built-in partners ship as data, not code, so they can be edited without a
/// release." Until this milestone they were a hardcoded map in
/// `lib/constants/personas.dart` — six entries with emoji icons, an `isPremium`
/// flag the client enforced, and prompts sitting in the APK for anyone to read.
/// All three of those were defects: §16 bans emoji in UI copy, F2 forbids
/// client-enforced entitlement, and R9.3.2 makes the prompt server-decided.
///
/// The columns are named explicitly because `select('*')` is refused: the
/// `system_prompt` grant is revoked from `authenticated`, and a table-wide
/// select therefore returns 42501 rather than silently succeeding.
class PartnerRepository {
  PartnerRepository(this._client);

  final SupabaseClient _client;

  /// Every partner the caller may use: the five built-ins, plus their own.
  ///
  /// Sorted here rather than in the query. Two chained `.order()` calls send
  /// two separate `order=` query parameters, and PostgREST does not combine
  /// them — asking for `is_builtin desc` then `difficulty asc` came back as
  /// Free Talk (1), Interviewer (3), Conversation Partner (2), Presentation
  /// Coach (3), Debate Opponent (4). Sorted on one axis and not the other,
  /// which is the worst of the three possible outcomes because it looks
  /// sorted.
  ///
  /// Five rows do not need a database sort, and a client-side one cannot be
  /// silently wrong about a comparator written in Dart.
  Future<Result<List<Partner>>> available() async {
    return Result.guardAsync(
      () async {
        final rows = await _selectPartners();
        final partners = rows.map(Partner.fromRow).toList();

        // Built-ins first, then easiest to hardest, then by name so the order
        // is stable when two share a difficulty. Someone picking their first
        // partner should meet Free Talk before Debate Opponent.
        partners.sort((a, b) {
          if (a.isBuiltin != b.isBuiltin) return a.isBuiltin ? -1 : 1;
          final byDifficulty = a.difficulty.compareTo(b.difficulty);
          return byDifficulty != 0 ? byDifficulty : a.name.compareTo(b.name);
        });
        return partners;
      },
      onError: mapPostgrestError,
    );
  }

  /// Selects the partner columns, tolerating a database that predates them.
  ///
  /// ## Why this exists
  ///
  /// `opening_line` (R4.1.3) is added by a migration. A client build always
  /// reaches users before — or without — the migration that matches it: an APK
  /// on a phone cannot be upgraded in lockstep with a schema, and during
  /// development the two drift by however long a `db push` is blocked.
  ///
  /// Two errors mean the same thing here and BOTH were seen on a device:
  ///
  /// * `42703` undefined_column — the migration has not been applied.
  /// * `42501` insufficient_privilege — the column exists and has no grant.
  ///   This table lost its table-level SELECT when Milestone 3 revoked
  ///   `system_prompt` at column level, so every column added afterwards starts
  ///   ungranted. The first version of this fallback matched only `42703` and
  ///   the partner rail came back empty anyway.
  ///
  /// PostgREST returns **nothing** for either. That is not a missing opening
  /// line — it is an empty partner rail and a disabled "Start speaking", so the
  /// entire product is unreachable because one decorative sentence is absent.
  ///
  /// So either error retries with the columns that have existed since Milestone
  /// 2. The feature degrades to the previous behaviour; nothing else does.
  ///
  /// This is not a workaround to be removed once the migration lands. It is the
  /// shape any additive column should be read with, and it costs one extra
  /// round trip exactly once per app run in the mismatched case.
  Future<List<Map<String, dynamic>>> _selectPartners() async {
    try {
      return await _client.from('partners').select(Partner.columns);
    } on PostgrestException catch (error) {
      if (error.code != _undefinedColumn && error.code != _insufficientPrivilege) {
        rethrow;
      }
      Log.w(
        'partners: the database is missing a column this build asks for '
        '(${error.message}). Falling back to the base columns — apply the '
        'pending migrations.',
      );
      return _client.from('partners').select(Partner.baseColumns);
    }
  }

  /// Postgres `undefined_column` — the migration has not run.
  static const _undefinedColumn = '42703';

  /// Postgres `insufficient_privilege` — the column exists but was never
  /// granted. See the note in [_selectPartners]: on this table that is the
  /// DEFAULT state of any newly added column.
  static const _insufficientPrivilege = '42501';
}
