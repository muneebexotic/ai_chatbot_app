import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/features/auth/application/auth_providers.dart';
import 'package:speakwise/features/partners/data/partner_repository.dart';
import 'package:speakwise/features/partners/domain/partner.dart';

final partnerRepositoryProvider = Provider<PartnerRepository>((ref) {
  return PartnerRepository(ref.watch(supabaseClientProvider));
});

/// The partners this user may talk to (§5.3.2).
///
/// There is no free/premium split applied here, and that is the point. The old
/// `Personas.getAvailablePersonas(isPremium)` filtered a hardcoded map by a
/// local boolean — a client deciding its own entitlement, which F2 forbids.
/// What a user may use is now a server fact: RLS returns the built-ins plus
/// their own rows, and the gateway independently refuses a partner the caller
/// has no claim to. The list here is what came back, not what we decided.
final partnersProvider = FutureProvider<List<Partner>>((ref) async {
  ref.watch(authStateProvider);
  final result = await ref.watch(partnerRepositoryProvider).available();
  return result.fold(ok: (partners) => partners, err: (failure) => throw failure);
});
