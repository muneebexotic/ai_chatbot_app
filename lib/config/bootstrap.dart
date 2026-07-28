// Firebase init, system UI, error handling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../core/config/app_config.dart';
import '../core/logging/log.dart';
import '../design/tokens/app_colors.dart';

class AppBootstrap {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // System UI style, for the frames before the stored theme is known.
    //
    // This runs before SharedPreferences is read, so it cannot know whether
    // the user is in light or dark. It sets the dark default (ThemeProvider
    // also defaults to dark); the AnnotatedRegion in main.dart takes over from
    // the first frame and follows the real theme. Do not add light-mode values
    // here — this is the pre-theme default, not a second source of truth.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: AppColors.dark.bg,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Firebase.initializeApp() stood here, tagged TODO(m3-delete) because
    // Firestore still backed chat history. Milestone 3 moved chat to Postgres
    // (§9.5 threads/messages), so the call, the three SDK packages, and the
    // last Firestore reference in the app went together. DECISIONS.md D0 has
    // the history: the project was suspended by Google, not migrated from.

    // Supabase (PRD §9.2). Nothing else backs the app now, so an unconfigured
    // build reaches a signed-out shell and nothing beyond it. It is still
    // tolerated rather than fatal here, because failing during bootstrap
    // produces a blank screen with no way to read the reason;
    // `AppConfig.assertConfigured` fails loudly at the first real call, which
    // is the moment the message is useful.
    if (AppConfig.hasSupabase) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // Not `anonKey`, which this SDK version deprecates in favour of this.
        // Confirms the naming chosen in AppConfig and .env.example rather than
        // leaving it a guess.
        publishableKey: AppConfig.supabasePublishableKey,
        // Sessions survive a restart. The default, stated explicitly because
        // turning it off silently signs everyone out on every cold start.
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
        ),
      );
      Log.i('Supabase initialised');
    } else {
      Log.w(
        'Supabase not configured — nothing will load. Pass '
        '--dart-define=SUPABASE_URL and --dart-define=SUPABASE_PUBLISHABLE_KEY. '
        'Point them at kalaam-dev while developing.',
      );
    }

    // Orientation lock
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // Optionally log to Crashlytics
    };
  }
}
