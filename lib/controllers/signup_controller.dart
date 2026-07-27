import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../utils/validation_utils.dart'; // Changed from validation_service
import '../constants/signup_constants.dart';
import 'package:ai_chatbot_app/core/logging/log.dart';
import 'package:ai_chatbot_app/core/result/result.dart';
import 'package:ai_chatbot_app/features/auth/presentation/auth_failure_copy.dart';

/// Controller for SignUp screen following clean architecture principles
/// 
/// Responsibilities:
/// - Handle business logic for user registration
/// - Manage form state and validation
/// - Coordinate with AuthProvider for authentication
/// - Provide reactive state updates to UI
/// 
/// Features:
/// - Separation of concerns from UI
/// - Robust error handling and logging
/// - Memory leak prevention
/// - Testable business logic
class SignUpController extends ChangeNotifier {
  /// Injected rather than looked up from a context (F3).
  final AuthProvider _auth;

  
  // Form controllers
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final GlobalKey<FormState> _formKey;
  
  // State variables
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isDisposed = false;

  // Getters
  TextEditingController get fullNameController => _fullNameController;
  TextEditingController get emailController => _emailController;
  TextEditingController get passwordController => _passwordController;
  GlobalKey<FormState> get formKey => _formKey;
  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;

  SignUpController({required AuthProvider auth}) : _auth = auth {
    _initializeControllers();
    _logControllerCreation();
  }

  /// Initialize form controllers
  void _initializeControllers() {
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _formKey = GlobalKey<FormState>();
  }

  /// Log controller creation for debugging
  void _logControllerCreation() {
    if (kDebugMode) {
      Log.d('SignUpController created at ${DateTime.now()}');
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    
    _disposeControllers();
    _isDisposed = true;
    super.dispose();
    
    if (kDebugMode) {
      Log.d('SignUpController disposed at ${DateTime.now()}');
    }
  }

  /// Dispose form controllers to prevent memory leaks
  void _disposeControllers() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    if (_isDisposed) return;
    
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  /// Set loading state safely
  void _setLoading(bool loading) {
    if (_isDisposed) return;
    
    _isLoading = loading;
    notifyListeners();
  }

  /// Validate the entire form
  bool validateForm() {
    return _formKey.currentState?.validate() ?? false;
  }

  /// Validate full name field - Using ValidationUtils
  String? validateFullName(String? value) {
    return ValidationUtils.validateFullName(value);
  }

  /// Validate email field - Using ValidationUtils
  String? validateEmail(String? value) {
    return ValidationUtils.validateEmail(value);
  }

  /// Validate password field - Using ValidationUtils with complexity
  String? validatePassword(String? value) {
    return ValidationUtils.validatePasswordComplex(value);
  }

  /// Navigate to chat screen - FIXED
  void navigateToChat() {
    final context = _formKey.currentContext;
    if (context == null || !context.mounted) return;
    
    // Clear entire navigation stack and navigate to chat
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/chat', // or use a constant
      (route) => false, // Remove ALL previous routes
    );
  }

  /// Navigate to photo upload for new users - FIXED
  void navigateToPhotoUpload() {
    final context = _formKey.currentContext;
    if (context == null || !context.mounted) return;
    
    // Clear stack and go to photo upload
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/photo-upload',
      (route) => false,
    );
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail({
    required Function(bool isNewUser) onSuccess,
    required Function(String error) onError,
  }) async {
    if (_isDisposed || _isLoading) return;

    _setLoading(true);
    
    try {
      final context = _formKey.currentContext;
      if (context == null) {
        throw Exception('Context not available');
      }

      final authProvider = _auth;
      
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      _logSignUpAttempt(email);

      final result = await authProvider.signUp(email, password, fullName);

      // Typed now (F4). The old call returned a bare bool, so "email already
      // registered" and "you are offline" arrived at the UI as the same
      // failure and got the same generic message — which §7.6 forbids, since
      // an error has to state its cause and its fix.
      switch (result) {
        case Err(:final failure):
          _logSignUpError(failure);
          onError(authFailureMessage(failure));
          return;
        case Ok():
          break;
      }

      // Wait for auth state to be ready
      await _waitForAuthReady(authProvider);

      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        _logSignUpSuccess(email);
        // Sign-up always produces a new account; the old `isNewUser` flag came
        // from Firebase's additionalUserInfo and was always true here.
        onSuccess(true);
      } else {
        throw Exception('Authentication succeeded but user state is incomplete');
      }

    } catch (e) {
      _logSignUpError(e);
      onError(_formatErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  /// Sign up with Google
  Future<void> signUpWithGoogle({
    required Function(bool isNewUser) onSuccess,
    required Function(String error) onError,
  }) async {
    if (_isDisposed || _isLoading) return;

    _setLoading(true);
    
    try {
      final context = _formKey.currentContext;
      if (context == null) {
        throw Exception('Context not available');
      }

      final authProvider = _auth;
      
      _logGoogleSignUpAttempt();

      await authProvider.signInWithGoogle();
      
      // Wait for auth state to be ready
      await _waitForAuthReady(authProvider);

      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        _logGoogleSignUpSuccess();
        onSuccess(false); // Google users are not considered "new" for flow purposes
      } else {
        throw Exception('Google authentication succeeded but user state is incomplete');
      }
      
    } catch (e) {
      _logGoogleSignUpError(e);
      onError(_formatErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  /// Wait for authentication state to be ready with timeout
  Future<void> _waitForAuthReady(AuthProvider authProvider) async {
    final completer = Completer<void>();
    Timer? timeoutTimer;
    
    // Set up timeout
    timeoutTimer = Timer(SignUpConstants.authTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException(
          'Authentication timeout after ${SignUpConstants.authTimeout.inSeconds}s',
        ));
      }
    });

    // Check auth state periodically
    final checkTimer = Timer.periodic(SignUpConstants.authCheckInterval, (timer) {
      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        timer.cancel();
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    try {
      await completer.future;
    } finally {
      checkTimer.cancel();
      timeoutTimer.cancel();
    }
  }

  /// Refresh authentication state (called on app resume)
  void refreshAuthState() {
    if (_isDisposed) return;
    
    // Could trigger a refresh of auth state if needed
    if (kDebugMode) {
      Log.d('Refreshing auth state at ${DateTime.now()}');
    }
  }

  /// Format error message for user display
  String _formatErrorMessage(dynamic error) {
    final errorStr = error.toString();
    
    // Common Firebase Auth error translations
    if (errorStr.contains('email-already-in-use')) {
      return 'This email is already registered. Please use a different email or try logging in.';
    } else if (errorStr.contains('weak-password')) {
      return 'Password is too weak. Please choose a stronger password.';
    } else if (errorStr.contains('invalid-email')) {
      return 'Invalid email address. Please check and try again.';
    } else if (errorStr.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorStr.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    } else if (errorStr.contains('TimeoutException')) {
      return 'Sign up is taking longer than expected. Please try again.';
    }
    
    // Generic error message
    return 'Sign up failed. Please try again.';
  }

  // Logging methods for debugging and monitoring
  void _logSignUpAttempt(String email) {
    if (kDebugMode) {
      Log.d('Attempting email sign up for: ${_obfuscateEmail(email)}');
    }
  }

  void _logSignUpSuccess(String email) {
    if (kDebugMode) {
      Log.d('Email sign up successful for: ${_obfuscateEmail(email)}');
    }
  }

  void _logSignUpError(dynamic error) {
    if (kDebugMode) {
      Log.d('Email sign up failed: $error');
    }
  }

  void _logGoogleSignUpAttempt() {
    if (kDebugMode) {
      Log.d('Attempting Google sign up');
    }
  }

  void _logGoogleSignUpSuccess() {
    if (kDebugMode) {
      Log.d('Google sign up successful');
    }
  }

  void _logGoogleSignUpError(dynamic error) {
    if (kDebugMode) {
      Log.d('Google sign up failed: $error');
    }
  }

  /// Obfuscate email for logging privacy
  String _obfuscateEmail(String email) {
    if (!email.contains('@')) return '***';
    final parts = email.split('@');
    final localPart = parts[0];
    final domain = parts[1];
    
    if (localPart.length <= 2) return '***@$domain';
    
    return '${localPart[0]}***${localPart[localPart.length - 1]}@$domain';
  }
}

/// Custom exception for timeout scenarios
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}