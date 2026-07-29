
import 'package:flutter/material.dart';

class WelcomeScreenConstants {
  // Animation Durations
  static const Duration animationDuration = Duration(milliseconds: 1200);
  
  // Animation Intervals
  static const Interval fadeInterval = Interval(0.0, 0.8, curve: Curves.easeOut);
  static const Interval slideInterval = Interval(0.2, 1.0, curve: Curves.easeOutCubic);
  static const Interval titleInterval = Interval(0.3, 1.0, curve: Curves.easeOut);
  static const Interval subtitleInterval = Interval(0.4, 1.0, curve: Curves.easeOut);
  static const Interval buttonsInterval = Interval(0.5, 1.0, curve: Curves.easeOut);
  
  // Animation Offsets
  static const Offset initialSlideOffset = Offset(0, 0.3);
  static const Offset titleSlideOffset = Offset(0, 0.2);
  static const Offset buttonsSlideOffset = Offset(0, 0.1);
  static const Offset zeroOffset = Offset.zero;
  
  // Spacing
  static const double horizontalPadding = 24.0;
  static const double verticalPadding = 32.0;
  static const double logoTitleSpacing = 32.0;
  static const double titleSubtitleSpacing = 16.0;
  static const double buttonSpacing = 16.0;
  static const double socialSectionSpacing = 48.0;
  static const double dividerSpacing = 32.0;
  static const double dividerHorizontalSpacing = 16.0;
  
  // Animation Values
  static const double fadeStart = 0.0;
  static const double fadeEnd = 1.0;
  static const double subtitleOpacity = 0.8;
  static const double dividerOpacity = 0.3;
  static const double dividerHeight = 1.0;
  
  // Flex Values
  static const int topSpacerFlex = 1;
  static const int bottomSpacerFlex = 2;
  static const int finalSpacerFlex = 1;
  
  // Gradient Colors
  static const List<Color> backgroundGradient = [
    Color(0xFF0A0A0A),
    Color(0xFF1A1A1A),
    Color(0xFF0A0A0A),
  ];
  
  // Gradient Stops
  static const List<double> gradientStops = [0.0, 0.5, 1.0];
  
  // Routes
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  /// Where a signed-in user lands.
  ///
  /// Milestone 4 pointed this at the session home. §4: "A Session is a live
  /// spoken conversation with an AI partner, followed by a report. It is the
  /// app's reason to exist and its highest-value screen. Build it as the centre
  /// of the product, not as a mode hidden behind a microphone icon." Landing on
  /// typed chat made chat the product and Sessions the mode.
  ///
  /// The name is kept so the three constants files stay in step; §5.1's typed
  /// chat is still one tap away and shares the same threads.
  static const String chatRoute = '/session';
  
  // UI text lives in lib/l10n/app_en.arb (R11.7), not here.
  //
  // It used to live here, and that is how "Welcome to ChadGPT" survived into
  // Milestone 3 — a product name nothing else in the app still used, on the
  // first screen a new user sees. A constant in `lib/constants/` is invisible
  // to a rule that looks at what gets passed to a Text widget, which is why
  // the R11.7 detector now reads prose out of this folder too.
  
  // Error Messages
  static const String googleSignInFailedPrefix = 'Google Sign-In failed: ';
  
  // SnackBar Configuration
  static const double snackBarBorderRadius = 12.0;
}