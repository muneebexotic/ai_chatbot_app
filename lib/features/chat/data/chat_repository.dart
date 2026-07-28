import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/features/chat/domain/chat_message.dart';
import 'package:speakwise/features/chat/domain/chat_thread.dart';

/// Reads and deletes threads and messages.
///
/// Notice what is missing: nothing here **writes** a message. The gateway does
/// that, inside the same request that authorised the model call, because a
/// client that can insert an assistant turn can fabricate a conversation and,
/// more to the point, can record a reply it never paid for.
///
/// Every query relies on RLS rather than on a `user_id` filter written here.
/// The policies from Milestone 2 restrict `threads` to the owner and reach
/// `messages` through the parent thread, and `test/rls/rls_policy_test.dart`
/// proves a second user cannot read the first's rows. Adding a redundant filter
/// would make this code look like the control, which is the reading that
/// eventually leads someone to remove the real one.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  /// Threads for the signed-in user, most recently active first.
  Future<Result<List<ChatThread>>> threads() async {
    return Result.guardAsync(
      () async {
        final rows = await _client
            .from('threads')
            .select('id, title, partner_id, updated_at')
            .order('updated_at', ascending: false)
            .limit(100);
        return rows.map(ChatThread.fromRow).toList();
      },
      onError: _mapPostgrest,
    );
  }

  /// Every turn in one thread, oldest first.
  Future<Result<List<ChatMessage>>> messages(String threadId) async {
    return Result.guardAsync(
      () async {
        final rows = await _client
            .from('messages')
            .select('id, role, content, created_at')
            .eq('thread_id', threadId)
            .order('created_at');
        return rows.map(ChatMessage.fromRow).toList();
      },
      onError: _mapPostgrest,
    );
  }

  /// Deletes a thread and, by cascade, its messages.
  Future<Result<void>> deleteThread(String threadId) async {
    return Result.guardAsync(
      () async {
        await _client.from('threads').delete().eq('id', threadId);
      },
      onError: _mapPostgrest,
    );
  }

  Future<Result<void>> renameThread(String threadId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const Err(InvalidRequestFailure(field: 'title'));
    }
    return Result.guardAsync(
      () async {
        await _client
            .from('threads')
            .update({'title': trimmed})
            .eq('id', threadId);
      },
      onError: _mapPostgrest,
    );
  }
}

/// Postgres and transport errors, mapped onto the taxonomy (F4).
///
/// Shared by all three repositories in this milestone. `42501` is
/// row-level-security refusing the statement, which is a real answer and not an
/// unknown failure — telling the user "something went wrong" when the truth is
/// "that is not yours" would be both vague and misleading.
AppFailure mapPostgrestError(Object error, StackTrace stackTrace) {
  if (error is PostgrestException) {
    Log.w('supabase: ${error.code} ${error.message}');
    return switch (error.code) {
      '42501' => UnauthorizedFailure(cause: error, stackTrace: stackTrace),
      '23505' => InvalidRequestFailure(cause: error, stackTrace: stackTrace),
      _ => UnknownFailure(cause: error, stackTrace: stackTrace),
    };
  }
  if (error is AuthException) {
    return UnauthorizedFailure(cause: error, stackTrace: stackTrace);
  }
  // Anything else reaching here is a socket, a DNS lookup, or a TLS handshake.
  // R11.5: this must read as "not sent", never as lost work.
  return OfflineFailure(cause: error, stackTrace: stackTrace);
}

const _mapPostgrest = mapPostgrestError;
