import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_chatbot_app/features/auth/application/auth_providers.dart';
import 'package:ai_chatbot_app/features/chat/application/chat_controller.dart';
import 'package:ai_chatbot_app/features/chat/application/chat_state.dart';
import 'package:ai_chatbot_app/features/chat/data/chat_repository.dart';
import 'package:ai_chatbot_app/features/chat/data/gateway_client.dart';
import 'package:ai_chatbot_app/features/chat/domain/chat_thread.dart';

/// The chat feature's slice of the graph (PRD F5, §9.1).

final gatewayClientProvider = Provider<GatewayClient>((ref) {
  final client = GatewayClient();
  ref.onDispose(client.dispose);
  return client;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

/// The caller's JWT, or null when signed out.
///
/// Read from the SDK's live session rather than cached at sign-in, because a
/// token that expired mid-conversation must not be sent — the gateway would
/// answer 401 and the user would see "your session ended" for a session that
/// is fine and merely needed refreshing.
final accessTokenProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession?.accessToken;
});

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

/// The conversation list.
///
/// A `FutureProvider` rather than state on the controller: the drawer and the
/// chat surface are separate concerns, and the old design — one `ChangeNotifier`
/// owning both — is why a streamed token used to rebuild the drawer.
final threadsProvider = FutureProvider<List<ChatThread>>((ref) async {
  // Recompute on sign-out, so one user's thread titles cannot survive into the
  // next user's drawer on a shared device.
  ref.watch(authStateProvider);
  final result = await ref.watch(chatRepositoryProvider).threads();
  return result.fold(ok: (threads) => threads, err: (failure) => throw failure);
});
