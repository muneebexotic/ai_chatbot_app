// TEMPORARY SCAFFOLDING — DELETE IN MILESTONE 2.
//
// The Firebase project is suspended, so sign-in fails and Chat and Settings —
// the two screens that carry the most theme-dependent code — are unreachable
// on a device. This file exists only so the Milestone 1 theme wiring can be
// verified with eyes on a real screen instead of by contrast table.
//
// It does not fix, work around, or substitute for auth. Milestone 2 replaces
// Firebase with Supabase and rewrites these screens; this file and the
// `kDebugMode` branch in `main.dart` that reaches it are deleted as part of
// that work. Both are marked `TODO(m2-delete)` so `grep` finds them.
//
// Guarded by `kDebugMode`, which is a compile-time constant, so the whole
// launcher is tree-shaken out of a release build.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../models/chat_message.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';

/// TODO(m2-delete): remove this file when Supabase auth lands.
///
/// Deliberately plain. This is a launcher, not a screen — styling it would
/// make it look like something worth keeping.
class DebugPreviewScreen extends ConsumerWidget {
  const DebugPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug launcher — not shipped')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Firebase is suspended, so sign-in cannot succeed. These entries '
              'push the real screens with fake state so the theme can be '
              'checked on a device.',
            ),
            const SizedBox(height: 24),

            // The only light/dark switch in the app lives in Settings, which is
            // behind the login that no longer works. Without this control the
            // light-mode pass is impossible to capture.
            OutlinedButton(
              onPressed: theme.toggleTheme,
              child: Text(
                theme.isDark ? 'Theme: dark — tap for light' : 'Theme: light — tap for dark',
              ),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: () {
                _seedChat(ref);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              child: const Text('Chat — with seeded messages'),
            ),
            const SizedBox(height: 12),

            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Settings'),
            ),
            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
              ),
              child: const Text('Normal flow — Splash, Welcome, Login'),
            ),
            const SizedBox(height: 24),

            const Text(
              'The conversation drawer reads Firestore and will come up empty '
              'or stalled. That is the suspended project, not the theme.',
            ),
          ],
        ),
      ),
    );
  }

  /// Fills the live [ChatProvider] message list so `ChatScreen` renders its
  /// populated branch rather than the empty state.
  ///
  /// This writes straight through the `messages` getter, which hands back the
  /// provider's own mutable `List` rather than a copy — a real encapsulation
  /// leak in `ChatProvider`, and the reason no production code had to change
  /// to make this work. Left alone rather than fixed: that class is rewritten
  /// as a `Notifier` in Milestone 3 (DECISIONS D5), and tightening the getter
  /// now would be a change to shipped code in service of a debug file.
  ///
  /// No `notifyListeners()` — seeding happens before the route is pushed, so
  /// the first build already sees the messages.
  void _seedChat(WidgetRef ref) {
    final chat = ref.read(chatNotifierProvider);
    if (chat.messages.isNotEmpty) return;

    final start = DateTime.now().subtract(const Duration(minutes: 6));

    chat.messages.addAll([
      ChatMessage.text(
        text: 'How do I stop saying "um" so much?',
        sender: 'user',
        timestamp: start,
      ),
      // Long, mixed-content, and markdown-bearing on purpose: headings, bold,
      // a list, inline code, and a fenced block are the cases where the serif
      // face, the mono face, and line height are easiest to judge.
      ChatMessage.text(
        text:
            'Filler words are a timing problem, not a vocabulary problem. You '
            'reach for "um" because your mouth is moving before the next '
            'sentence has finished forming.\n\n'
            '### What actually works\n\n'
            '1. **Pause instead.** Silence sounds far shorter to a listener '
            'than it feels to you.\n'
            '2. **Slow the first sentence.** Most filler clusters in the '
            'opening fifteen seconds.\n'
            '3. **Record yourself.** You cannot fix a rate you have never '
            'measured.\n\n'
            'A useful target is under `3` fillers per minute. Below that, '
            'nobody notices; above `8`, it is the thing they remember.\n\n'
            '```\nsession 04  ·  6m 12s  ·  fillers 7/min  ·  pace 148 wpm\n```\n\n'
            'The pause is the whole technique. Everything else is practice.',
        sender: 'bot',
        timestamp: start.add(const Duration(seconds: 4)),
      ),
      ChatMessage.text(
        text:
            'That makes sense. I think I speed up when I am nervous, and then '
            'I run out of sentence halfway through and have to fill the gap '
            'with something.',
        sender: 'user',
        timestamp: start.add(const Duration(minutes: 2)),
      ),
      ChatMessage.text(
        text:
            'Then the fix is upstream of the filler. Slow the open, and the '
            'gap never appears.',
        sender: 'bot',
        timestamp: start.add(const Duration(minutes: 2, seconds: 3)),
      ),
    ]);
  }
}
