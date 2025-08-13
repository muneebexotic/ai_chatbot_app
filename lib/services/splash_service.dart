// Business logic for splash initialization

import 'dart:async';
import 'dart:developer' as dev;
import '../providers/auth_provider.dart';
import '../constants/splash_constants.dart';

/// Service responsible for handling splash screen initialization logic
class SplashService {
  static const String _logTag = 'SplashService';

  /// Waits for both minimum splash time and auth initialization
  /// Returns the navigation route based on auth state
  static Future<String> initializeApp(AuthProvider authProvider) async {
    try {
      _log('Starting app initialization');

      // Wait for both conditions in parallel
      await Future.wait([
        _waitForMinimumSplashTime(),
        _waitForAuthInitialization(authProvider),
      ]);

      return _determineNavigationRoute(authProvider);
    } catch (e, stackTrace) {
      _logError('Error during app initialization', e, stackTrace);
      
      // Fallback: wait a bit more then determine route
      await Future.delayed(SplashConstants.fallbackDelay);
      return _determineNavigationRoute(authProvider);
    }
  }

  /// Ensures minimum splash screen display time for UX
  static Future<void> _waitForMinimumSplashTime() async {
    _log('Waiting for minimum splash time...');
    await Future.delayed(SplashConstants.minimumSplashDuration);
    _log('Minimum splash time completed');
  }

  /// Waits for auth provider to be fully initialized
  static Future<void> _waitForAuthInitialization(AuthProvider authProvider) async {
    // If no Firebase user, no need to wait
    if (authProvider.user == null) {
      _log(SplashConstants.noUserMessage);
      return;
    }

    _log(SplashConstants.waitingForAuthMessage);
    
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < SplashConstants.authTimeoutDuration) {
      // Check if auth provider has finished loading user data
      if (authProvider.currentUser != null) {
        _log('${SplashConstants.authCompletedMessage} ${stopwatch.elapsedMilliseconds}ms');
        return;
      }
      
      // Wait before next check
      await Future.delayed(SplashConstants.authCheckInterval);
    }
    
    // Timeout reached
    _log('${SplashConstants.authTimeoutMessage} ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Determines which route to navigate to based on auth state
  static String _determineNavigationRoute(AuthProvider authProvider) {
    final hasFirebaseUser = authProvider.user != null;
    final hasUserData = authProvider.currentUser != null;
    final isFullyLoggedIn = hasFirebaseUser && hasUserData;

    _logNavigationDecision(hasFirebaseUser, hasUserData, isFullyLoggedIn, authProvider);

    if (isFullyLoggedIn) {
      _log(SplashConstants.navigatingToChatMessage);
      return SplashConstants.chatRoute;
    } else {
      _log(SplashConstants.navigatingToWelcomeMessage);
      return SplashConstants.welcomeRoute;
    }
  }

  /// Logs navigation decision details
  static void _logNavigationDecision(
    bool hasFirebaseUser, 
    bool hasUserData, 
    bool isFullyLoggedIn, 
    AuthProvider authProvider
  ) {
    _log(SplashConstants.navigationDecisionMessage);
    _log('   Firebase user: $hasFirebaseUser');
    _log('   User data: $hasUserData');
    _log('   Fully logged in: $isFullyLoggedIn');
    _log('   Premium status: ${authProvider.currentUser?.hasActiveSubscription}');
  }

  static void _log(String message) {
    dev.log(message, name: _logTag);
  }

  static void _logError(String message, Object error, StackTrace stackTrace) {
    dev.log(
      '$message: $error',
      name: _logTag,
      error: error,
      stackTrace: stackTrace,
    );
  }
}