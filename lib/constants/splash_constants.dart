// All splash-related constants

class SplashConstants {
  // Animation durations
  static const Duration animationDuration = Duration(milliseconds: 1500);
  static const Duration minimumSplashDuration = Duration(milliseconds: 2500);
  static const Duration authTimeoutDuration = Duration(seconds: 10);
  static const Duration authCheckInterval = Duration(milliseconds: 100);
  static const Duration fallbackDelay = Duration(milliseconds: 1000);

  // Animation intervals
  static const double fadeStart = 0.0;
  static const double fadeEnd = 0.7;
  static const double scaleStart = 0.2;
  static const double scaleEnd = 1.0;
  static const double slideStart = 0.4;
  static const double slideEnd = 1.0;
  static const double subtitleStart = 0.6;
  static const double subtitleEnd = 1.0;
  static const double loadingStart = 0.8;
  static const double loadingEnd = 1.0;

  // Animation values
  static const double fadeBegin = 0.0;
  static const double fadeComplete = 1.0;
  static const double scaleBegin = 0.8;
  static const double scaleComplete = 1.0;
  static const double subtitleOpacity = 0.7;
  static const double loadingOpacity = 0.5;

  // UI constants
  static const double logoSpacing = 32.0;
  static const double subtitleSpacing = 16.0;
  static const double loadingSpacing = 48.0;
  static const double loadingIndicatorSize = 24.0;
  static const double loadingStrokeWidth = 2.0;

  // Route names
  static const String chatRoute = '/chat';
  static const String welcomeRoute = '/welcome';

  // Log messages
  static const String noUserMessage = '✅ No user, skipping auth initialization wait';
  static const String waitingForAuthMessage = '🔄 Waiting for auth initialization...';
  static const String authCompletedMessage = '✅ Auth initialization completed in';
  static const String authTimeoutMessage = '⚠️ Auth initialization timeout after';
  static const String navigationDecisionMessage = '🧭 Navigation decision:';
  static const String navigatingToChatMessage = '✅ Navigating to chat screen';
  static const String navigatingToWelcomeMessage = '✅ Navigating to welcome screen';
  static const String errorMessage = '❌ Error during splash initialization:';
}