// Firebase init, system UI, error handling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
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

    // Firebase. Auth is gone from it as of Milestone 2 — nothing in lib/
    // imports firebase_auth — but Firestore still backs chat history and the
    // conversation list, so the SDK still has to start.
    //
    // TODO(m3-delete): retagged from m2. Milestone 3 rebuilds chat on Postgres
    // (§9.5 threads/messages), and this call goes with the last Firestore
    // reference. Leaving it labelled m2 would have made a marker that was
    // already overdue on the day the milestone closed.
    await Firebase.initializeApp();

    // Supabase (PRD §9.2). Tolerates being unconfigured so the app still runs
    // from an IDE with no --dart-define set — Firebase carries it until the
    // port completes. `AuthRepository` is what fails loudly when a Supabase
    // call is actually attempted without configuration, which is the moment
    // the error is useful.
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
        'Supabase not configured — running on Firebase only. Pass '
        '--dart-define=SUPABASE_URL and --dart-define=SUPABASE_PUBLISHABLE_KEY '
        'to exercise the Milestone 2 auth path.',
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
