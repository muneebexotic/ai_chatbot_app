import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_chatbot_app/core/result/result.dart';
import 'package:ai_chatbot_app/features/chat/data/chat_repository.dart'
    show mapPostgrestError;
import 'package:ai_chatbot_app/features/partners/domain/partner.dart';

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
  /// Ordered by difficulty so the rail reads from easiest to hardest, which is
  /// the order someone picking their first one wants.
  Future<Result<List<Partner>>> available() async {
    return Result.guardAsync(
      () async {
        final rows = await _client
            .from('partners')
            .select(Partner.columns)
            .order('is_builtin', ascending: false)
            .order('difficulty');
        return rows.map(Partner.fromRow).toList();
      },
      onError: mapPostgrestError,
    );
  }
}
