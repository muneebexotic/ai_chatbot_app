import 'package:supabase_flutter/supabase_flutter.dart';

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
        final rows = await _client.from('partners').select(Partner.columns);
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
}
