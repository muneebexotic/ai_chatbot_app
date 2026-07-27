// Firebase init, system UI, error handling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

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

    // Firebase
    await Firebase.initializeApp();

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
