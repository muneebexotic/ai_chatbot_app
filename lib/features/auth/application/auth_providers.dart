import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'package:ai_chatbot_app/features/auth/data/auth_repository.dart';
import 'package:ai_chatbot_app/features/auth/domain/auth_user.dart';

/// The Riverpod graph for authentication (PRD F5, §9.1).
///
/// These are real `Notifier`-era providers rather than the
/// `ChangeNotifierProvider` shims the rest of the app still uses. DECISIONS D5
/// time-boxed those to "until the feature is rebuilt"; auth is the first
/// feature being rebuilt, so it does not inherit them.

/// The raw SDK client.
///
/// Separate from the repository so a test can substitute a client without the
/// repository knowing, and so exactly one place in the app reaches for the
/// singleton.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in identity, or null.
///
/// A stream rather than a value cached at sign-in, because a session can also
/// end for reasons no call site initiated: the refresh token was revoked, the
/// password was changed on another device, the account was deleted. Anything
/// caching the result of `signIn()` would keep showing a signed-in shell over
/// a dead session.
///
/// `AsyncValue` carries the third state the old `isLoggedIn` getter could not
/// express: *not yet known*. The previous code read `_firebaseUser != null &&
/// _currentUser != null`, which is indistinguishable from "signed out" during
/// the restore-session round trip — and that is why the splash screen had to
/// guess.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);

  // Seed with what the SDK already restored from disk, so a returning user
  // does not flash through a signed-out frame before the first stream event.
  return repository.authStateChanges;
});

/// The current user, or null — including while the first event is pending.
///
/// Convenience for widgets that genuinely do not care about the loading state.
/// Prefer watching [authStateProvider] and rendering all three cases; reach
/// for this only where "not yet known" and "signed out" really do look the
/// same.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Whether a session exists right now, read synchronously off the SDK.
///
/// Does not wait for the stream, so it is safe in a router redirect where an
/// `AsyncValue.loading` would send a returning user to the welcome screen.
final isSignedInProvider = Provider<bool>((ref) {
  // Depend on the stream so this recomputes when auth changes, but answer from
  // the synchronous session rather than from the async snapshot.
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).isSignedIn;
});
