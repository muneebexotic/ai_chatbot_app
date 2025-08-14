import 'package:flutter/material.dart';

/// Constants for SignUp screen
/// 
/// Centralizes all configuration values, strings, and design tokens
/// for better maintainability and consistency
class SignUpConstants {
  // Private constructor to prevent instantiation
  SignUpConstants._();

  // Animation Durations
  static const Duration mainAnimationDuration = Duration(milliseconds: 1000);
  static const Duration authTimeout = Duration(seconds: 10);
  static const Duration authCheckInterval = Duration(milliseconds: 200);
  static const Duration errorDisplayDuration = Duration(seconds: 4);

  // Spacing Constants
  static const double screenPadding = 24.0;
  static const double sectionSpacing = 40.0;
  static const double largeSpacing = 48.0;
  static const double buttonSpacing = 32.0;
  static const double inputSpacing = 24.0;
  static const double bottomSpacing = 32.0;

  // Design Tokens
  static const double borderRadius = 12.0;

  // Colors
  static const List<Color> backgroundGradient = [
    Color(0xFF0A0A0A),
    Color(0xFF1A1A1A),
    Color(0xFF0A0A0A),
  ];
  
  static const List<double> gradientStops = [0.0, 0.5, 1.0];

  // Text Content
  static const String headerLine1 = 'Create Your';
  static const String headerLine2 = 'Account';
  
  static const String fullNameLabel = 'Full Name';
  static const String fullNameHint = 'Enter your full name';
  
  static const String emailLabel = 'Email Address';
  static const String emailHint = 'Enter your email';
  
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Create a strong password';
  
  static const String signUpButtonText = 'Create Account';
  static const String loginPrompt = "Already have an account? ";
  static const String loginButtonText = 'Login';
  
  static const String dividerText = 'or continue with';

  // Validation Messages
  static const String fullNameRequiredError = 'Please enter your full name';
  static const String fullNameTooShortError = 'Name must be at least 2 characters';
  static const String emailRequiredError = 'Please enter your email';
  static const String emailInvalidError = 'Please enter a valid email';
  static const String passwordRequiredError = 'Please enter a password';
  static const String passwordTooShortError = 'Password must be at least 6 characters';
  static const String passwordWeakError = 'Password must contain letters and numbers';

  // Validation Rules
  static const int minNameLength = 2;
  static const int minPasswordLength = 6;

  // Regular Expressions
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}'
  ;
  static const String passwordRegex = r'^(?=.*[a-zA-Z])(?=.*\d)';

  // Semantic Labels (Accessibility)
  static const String backButtonSemanticLabel = 'Go back to previous screen';
  static const String fullNameFieldSemanticLabel = 'Enter your full name';
  static const String emailFieldSemanticLabel = 'Enter your email address';
  static const String passwordFieldSemanticLabel = 'Enter your password';
  static const String passwordToggleSemanticLabel = 'Toggle password visibility';
  static const String signUpButtonSemanticLabel = 'Create new account';
  static const String googleButtonSemanticLabel = 'Sign up with Google';
  static const String loginLinkSemanticLabel = 'Go to login screen';

  // Error Logging Tags
  static const String logTagController = 'SignUpController';
  static const String logTagAuth = 'SignUpAuth';
  static const String logTagValidation = 'SignUpValidation';
}