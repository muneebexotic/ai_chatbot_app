import 'dart:ui';

/// Constants for the login screen
class LoginConstants {
  // Animation durations
  static const Duration animationDuration = Duration(milliseconds: 1000);
  static const Duration userDataTimeout = Duration(seconds: 5);
  static const Duration checkInterval = Duration(milliseconds: 150);
  static const Duration settlementDelay = Duration(milliseconds: 50);

  // Animation intervals
  static const double fadeStartInterval = 0.0;
  static const double fadeEndInterval = 0.8;
  static const double slideStartInterval = 0.2;
  static const double slideEndInterval = 1.0;
  static const double emailAnimationStart = 0.3;
  static const double passwordAnimationStart = 0.4;
  static const double buttonAnimationStart = 0.5;

  // Slide offsets
  static const Offset initialSlideOffset = Offset(0, 0.2);
  static const Offset inputSlideOffset = Offset(0, 0.1);
  static const Offset finalSlideOffset = Offset.zero;

  // Validation constants
  static const int minPasswordLength = 6;
  static const String emailRegexPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';

  // UI spacing
  static const double screenPadding = 24.0;
  static const double titleTopSpacing = 40.0;
  static const double titleBottomSpacing = 48.0;
  static const double inputSpacing = 24.0;
  static const double forgotPasswordSpacing = 16.0;
  static const double loginButtonSpacing = 32.0;
  static const double signUpLinkSpacing = 24.0;
  static const double dividerSpacing = 40.0;
  static const double socialButtonSpacing = 32.0;

  // Colors
  static const int primaryBackgroundColor = 0xFF0A0A0A;
  static const int secondaryBackgroundColor = 0xFF1A1A1A;

  // Route names
  static const String welcomeRoute = '/welcome';
  static const String chatRoute = '/chat';
  static const String signupRoute = '/signup';
  static const String forgotPasswordRoute = '/forgot-password';

  // Error messages
  static const String emailRequiredError = 'Please enter your email';
  static const String emailValidationError = 'Please enter a valid email';
  static const String passwordRequiredError = 'Please enter your password';
  static const String passwordLengthError = 'Password must be at least 6 characters';
  static const String googleSignInError = 'Google Sign-In failed';
  static const String userDataTimeoutWarning = '⚠️ Timeout waiting for user data';

  // Labels and text
  static const String emailLabel = 'Email Address';
  static const String emailHint = 'Enter your email';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Enter your password';
  static const String forgotPasswordText = 'Forgot password?';
  static const String loginButtonText = 'Login';
  static const String signUpPrompt = "Don't have an account? ";
  static const String signUpText = 'Sign Up';
  static const String dividerText = 'or continue with';
  static const String titleLine1 = 'Login Your';
  static const String titleLine2 = 'Account';
}