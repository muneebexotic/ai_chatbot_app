import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/features/chat/data/chat_repository.dart'
    show mapPostgrestError;
import 'package:speakwise/features/memory/domain/memory_item.dart';

/// Reading and forgetting (PRD §5.2.2).
///
/// "Memory is visible and editable: a Memory screen lists every stored item
/// with its date, each deletable, with a 'forget everything' action. Most
/// competitors hide this. Showing it is a trust feature and a differentiator."
///
/// Note the asymmetry, which is the RLS design showing through: the client can
/// **read and delete** memories but never writes one. Writing is the extraction
/// function's job under service role, after the R5.2.4 filter has run. A client
/// that could insert could bypass the filter entirely, which would make the
/// filter decorative.
class MemoryRepository {
  MemoryRepository(this._client);

  final SupabaseClient _client;

  Future<Result<List<MemoryItem>>> all() async {
    return Result.guardAsync(
      () async {
        final rows = await _client
            .from('memories')
            .select('id, content, created_at')
            .order('created_at', ascending: false);
        return rows.map(MemoryItem.fromRow).toList();
      },
      onError: mapPostgrestError,
    );
  }

  Future<Result<void>> forget(String id) async {
    return Result.guardAsync(
      () async {
        await _client.from('memories').delete().eq('id', id);
      },
      onError: mapPostgrestError,
    );
  }

  /// R5.2.2's "forget everything".
  ///
  /// No `where` beyond RLS: the policy scopes the delete to the caller's own
  /// rows, and adding `eq('user_id', ...)` here would put the actual protection
  /// in the least trustworthy place.
  Future<Result<void>> forgetAll() async {
    return Result.guardAsync(
      () async {
        // PostgREST refuses an unfiltered DELETE, which is a good default and a
        // nuisance here. `not.is.null` on the primary key matches every row the
        // policy already allows and nothing it does not.
        await _client.from('memories').delete().not('id', 'is', null);
      },
      onError: mapPostgrestError,
    );
  }

  /// Asks the server to extract facts from a finished exchange (R5.2.1).
  ///
  /// Fire-and-forget by design. Nobody is waiting for this, it costs a model
  /// call the user did not ask for, and a failure means one unremembered fact —
  /// so it never surfaces an error and never blocks a reply. The result is
  /// logged and dropped.
  Future<void> extractFrom(String threadId) async {
    try {
      final response = await _client.functions.invoke(
        'extract-memory',
        body: {'threadId': threadId},
      );
      Log.d('memory: extraction returned ${response.data}');
    } catch (error) {
      Log.w('memory: extraction failed', error: error);
    }
  }
}
