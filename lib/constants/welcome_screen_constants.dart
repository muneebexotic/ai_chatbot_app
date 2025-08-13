import 'dart:ui';

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
  static const String chatRoute = '/chat';
  
  // UI Text
  static const String welcomeTitle = 'Welcome to ChadGPT';
  static const String welcomeSubtitle = 'Your AI companion for intelligent conversations';
  static const String loginButtonText = 'Login';
  static const String signupButtonText = 'Sign Up';
  static const String dividerText = 'or continue with';
  
  // Error Messages
  static const String googleSignInFailedPrefix = 'Google Sign-In failed: ';
  
  // SnackBar Configuration
  static const double snackBarBorderRadius = 12.0;
}