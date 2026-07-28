import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/features/auth/application/auth_providers.dart';
import 'package:speakwise/features/chat/application/chat_controller.dart';
import 'package:speakwise/features/chat/application/chat_state.dart';
import 'package:speakwise/features/chat/data/chat_repository.dart';
import 'package:speakwise/features/chat/data/gateway_client.dart';
import 'package:speakwise/features/chat/domain/chat_thread.dart';
import 'package:speakwise/features/partners/application/partner_providers.dart';
import 'package:speakwise/features/partners/domain/partner.dart';

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

/// The partner the next message goes to.
///
/// Derived rather than stored, so a partner list that reloads cannot reset the
/// conversation — see the note in `ChatController.build`. Falls back to the
/// first of the sorted list, which is Free Talk: a new account should meet the
/// gentlest partner first, not Debate Opponent.
final activePartnerProvider = Provider<Partner?>((ref) {
  final partners = ref.watch(partnersProvider).valueOrNull;
  if (partners == null || partners.isEmpty) return null;

  final chosen = ref.watch(chatControllerProvider).partnerId;
  if (chosen == null) return partners.first;
  return partners.where((p) => p.id == chosen).firstOrNull ?? partners.first;
});

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
