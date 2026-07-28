import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/forgot_password_controller.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/themes_provider.dart';
import '../features/auth/application/auth_providers.dart';

/// The application's dependency graph (PRD F5).
///
/// Replaces `MultiProvider` + `ChangeNotifierProxyProvider` from
/// `package:provider`, which is now removed from `pubspec.yaml`.
///
/// ## Why the state classes are still `ChangeNotifier`
///
/// Riverpod's `ChangeNotifierProvider` is the documented migration path off
/// `package:provider`, and it is what makes this a single-step, verifiable
/// change rather than a simultaneous rewrite of six stateful classes totalling
/// several thousand lines. The value F5 is actually after — "removes F3
/// cleanly and makes quota/entitlement state testable" — comes from the
/// dependency *injection*, which is done: nothing below reaches for a
/// `BuildContext`, and every class here can be constructed in a test.
///
/// Each of these becomes a proper `Notifier` as its feature is rebuilt in
/// Milestones 2–5, at which point it is a rewrite of code that is being
/// rewritten anyway. Logged as `DECISIONS.md` D5.
///
/// ## The dependency chain
///
/// `auth` → `subscription`, `conversations`, `chat`; `settings` → `chat`.
/// `ref.watch` inside a provider body recreates the dependent when its
/// dependency changes, which is what `ChangeNotifierProxyProvider` was doing
/// by hand.

/// Light/dark and theme mode.
final themeNotifierProvider = ChangeNotifierProvider<ThemeProvider>(
  (ref) => ThemeProvider(),
);

/// Firebase auth, the current user, and usage counters.
///
/// Session state, backed by Supabase since Milestone 2 (PRD §9.2).
///
/// The repository is injected rather than constructed inside, so this graph
/// can be pointed at a test double without the provider knowing.
final authNotifierProvider = ChangeNotifierProvider<AuthProvider>(
  (ref) => AuthProvider(ref.watch(authRepositoryProvider)),
);

final forgotPasswordControllerProvider =
    ChangeNotifierProvider<ForgotPasswordController>(
      (ref) => ForgotPasswordController(),
    );

/// Theme, persona, voice, and haptics preferences.
final settingsNotifierProvider = ChangeNotifierProvider<SettingsProvider>((ref) {
  final settings = SettingsProvider();
  // Deferred so the first frame is not blocked on disk I/O.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    settings.initializeSettings();
  });
  return settings;
});

/// Play Billing state. Reads the payment service off auth.
final subscriptionNotifierProvider = ChangeNotifierProvider<SubscriptionProvider>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return SubscriptionProvider(auth.paymentService);
});

/// The conversation list for the signed-in user.
final conversationsNotifierProvider = ChangeNotifierProvider<ConversationsProvider>((
  ref,
) {
  final auth = ref.watch(authNotifierProvider);
  return ConversationsProvider(userId: auth.user?.id ?? '');
});

/// Chat state for the current thread.
///
/// Everything it needs is passed in: the user id, the auth provider for quota
/// checks, a plain function that reads the selected persona, and a callback to
/// refresh the conversation list. It never sees a `BuildContext` — that was F3.
final chatNotifierProvider = ChangeNotifierProvider<ChatProvider>((ref) {
  final auth = ref.watch(authNotifierProvider);

  return ChatProvider(
    userId: auth.user?.id ?? '',
    auth: auth,
    // Read lazily so a persona change takes effect on the next message
    // without rebuilding the provider or discarding the thread.
    persona: () => ref.read(settingsNotifierProvider).persona,
    onConversationsChanged: () => ref.read(conversationsNotifierProvider).loadConversations(),
  );
});
