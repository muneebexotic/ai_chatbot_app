import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/forgot_password_controller.dart';
import '../providers/auth_provider.dart';
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

// `chatNotifierProvider` and `conversationsNotifierProvider` were here. Both
// are gone: the chat feature owns its own graph now, in
// `features/chat/application/chat_providers.dart`, built on real `Notifier`
// and `FutureProvider` rather than the `ChangeNotifierProvider` shims above.
//
// That is D5 being honoured rather than extended. It time-boxed the shims to
// "until the feature is rebuilt, at which point it is a rewrite of code
// already being rewritten", and named chat as Milestone 3. Four shims remain —
// theme, auth, settings, subscription — each waiting for its own milestone.
