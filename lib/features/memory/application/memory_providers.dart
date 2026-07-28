import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_chatbot_app/features/auth/application/auth_providers.dart';
import 'package:ai_chatbot_app/features/memory/data/memory_repository.dart';
import 'package:ai_chatbot_app/features/memory/domain/memory_item.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ref.watch(supabaseClientProvider));
});

/// Everything the app has stored about this user (§5.2.2).
final memoriesProvider = FutureProvider<List<MemoryItem>>((ref) async {
  ref.watch(authStateProvider);
  final result = await ref.watch(memoryRepositoryProvider).all();
  return result.fold(ok: (items) => items, err: (failure) => throw failure);
});
