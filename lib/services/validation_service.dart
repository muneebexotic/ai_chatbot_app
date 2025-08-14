import 'package:flutter/foundation.dart';
import '../constants/signup_constants.dart';

/// Enhanced validation service with comprehensive validation rules
/// 
/// Features:
/// - Centralized validation logic
/// - Consistent error messages
/// - Input sanitization
/// - Security best practices
/// - Extensible validation patterns
/// - Performance optimized
class ValidationService {
  // Private constructor to prevent instantiation
  ValidationService._();

  // Compiled regex patterns for performance
  static final RegExp _emailRegex = RegExp(SignUpConstants.emailRegex);
  static final RegExp _passwordRegex = RegExp(SignUpConstants.passwordRegex);
  static final RegExp _nameRegex = RegExp(r'^[a-zA-Z\s\u00C0-\u017F\u0100-\u024F]+$');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  /// Validate full name field
  /// 
  /// Rules:
  /// - Required field
  /// - Minimum length
  /// - Contains only letters, spaces, and accented characters
  /// - No excessive whitespace
  static String? validateFullName(String? value) {
    try {
      // Check if empty or null
      if (value == null || value.trim().isEmpty) {
        return SignUpConstants.fullNameRequiredError;
      }

      // Sanitize input
      final sanitizedValue = _sanitizeInput(value);

      // Check minimum length
      if (sanitizedValue.length < SignUpConstants.minNameLength) {
        return SignUpConstants.fullNameTooShortError;
      }

      // Check if contains valid characters
      if (!_nameRegex.hasMatch(sanitizedValue)) {
        return 'Name can only contain letters and spaces';
      }

      // Check for excessive whitespace
      if (_hasExcessiveWhitespace(sanitizedValue)) {
        return 'Please remove extra spaces from your name';
      }

      return null; // Valid
    } catch (e) {
      _logValidationError('validateFullName', e);
      return 'Invalid name format';
    }
  }

  /// Validate email field
  /// 
  /// Rules:
  /// - Required field
  /// - Valid email format
  /// - Reasonable length limits
  /// - No dangerous characters
  static String? validateEmail(String? value) {
    try {
      // Check if empty or null
      if (value == null || value.trim().isEmpty) {
        return SignUpConstants.emailRequiredError;
      }

      // Sanitize input
      final sanitizedValue = _sanitizeInput(value);

      // Check length limits
      if (sanitizedValue.length > 254) { // RFC 5321 limit
        return 'Email address is too long';
      }

      // Check email format
      if (!_emailRegex.hasMatch(sanitizedValue)) {
        return SignUpConstants.emailInvalidError;
      }

      // Additional security checks
      if (_containsDangerousCharacters(sanitizedValue)) {
        return 'Email contains invalid characters';
      }

      return null; // Valid
    } catch (e) {
      _logValidationError('validateEmail', e);
      return 'Invalid email format';
    }
  }

  /// Validate password field
  /// 
  /// Rules:
  /// - Required field
  /// - Minimum length
  /// - Contains letters and numbers
  /// - No common weak patterns
  /// - Security best practices
  static String? validatePassword(String? value) {
    try {
      // Check if empty or null
      if (value == null || value.isEmpty) {
        return SignUpConstants.passwordRequiredError;
      }

      // Check minimum length
      if (value.length < SignUpConstants.minPasswordLength) {
        return SignUpConstants.passwordTooShortError;
      }

      // Check maximum length (prevent DoS)
      if (value.length > 128) {
        return 'Password is too long (maximum 128 characters)';
      }

      // Check complexity requirements
      if (!_passwordRegex.hasMatch(value)) {
        return SignUpConstants.passwordWeakError;
      }

      // Check for common weak patterns
      if (_isWeakPassword(value)) {
        return 'Please choose a stronger password';
      }

      return null; // Valid
    } catch (e) {
      _logValidationError('validatePassword', e);
      return 'Invalid password format';
    }
  }

  /// Validate confirm password field
  static String? validateConfirmPassword(String? value, String? originalPassword) {
    try {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }

      if (value != originalPassword) {
        return 'Passwords do not match';
      }

      return null; // Valid
    } catch (e) {
      _logValidationError('validateConfirmPassword', e);
      return 'Password confirmation failed';
    }
  }

  /// Generic phone number validation (if needed for future features)
  static String? validatePhoneNumber(String? value) {
    try {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your phone number';
      }

      final sanitizedValue = value.replaceAll(RegExp(r'[^\d+\-\(\)\s]'), '');
      final digitsOnly = sanitizedValue.replaceAll(RegExp(r'[^\d]'), '');

      if (digitsOnly.length < 10 || digitsOnly.length > 15) {
        return 'Please enter a valid phone number';
      }

      return null; // Valid
    } catch (e) {
      _logValidationError('validatePhoneNumber', e);
      return 'Invalid phone number format';
    }
  }

  // Helper Methods

  /// Sanitize input by trimming and normalizing whitespace
  static String _sanitizeInput(String input) {
    return input.trim().replaceAll(_whitespaceRegex, ' ');
  }

  /// Check for excessive whitespace patterns
  static bool _hasExcessiveWhitespace(String input) {
    return input.contains(RegExp(r'\s{2,}')) || 
           input.startsWith(' ') || 
           input.endsWith(' ');
  }

  /// Check for potentially dangerous characters
  static bool _containsDangerousCharacters(String input) {
    // Check for common injection patterns and control characters
    final dangerousPatterns = [
      RegExp(r'[<>"\]'), // HTML/XML injection
      RegExp(r'[\x00-\x1F\x7F]'), // Control characters
      RegExp(r'(javascript:|data:|vbscript:)', caseSensitive: false), // Script injection
    ];

    return dangerousPatterns.any((pattern) => pattern.hasMatch(input));
  }

  /// Check for common weak password patterns
  static bool _isWeakPassword(String password) {
    final lowercasePassword = password.toLowerCase();
    
    // Common weak patterns
    final weakPatterns = [
      'password',
      '123456',
      'qwerty',
      'abc123',
      'password123',
      '12345678',
    ];

    // Check for weak patterns
    for (final pattern in weakPatterns) {
      if (lowercasePassword.contains(pattern)) {
        return true;
      }
    }

    // Check for repeated characters (e.g., 'aaaa', '1111')
    if (RegExp(r'^(.)\1{3,}').hasMatch(password)) {
      return true;
    }

    // Check for simple sequences (e.g., '1234', 'abcd')
    if (_isSequentialString(password)) {
      return true;
    }

    return false; // Strong enough
  }

  /// Check if string contains sequential characters
  static bool _isSequentialString(String input) {
    if (input.length < 4) return false;

    for (int i = 0; i < input.length - 3; i++) {
      final substring = input.substring(i, i + 4);
      
      // Check for ascending sequence
      bool isAscending = true;
      for (int j = 1; j < substring.length; j++) {
        if (substring.codeUnitAt(j) != substring.codeUnitAt(j - 1) + 1) {
          isAscending = false;
          break;
        }
      }
      
      // Check for descending sequence
      bool isDescending = true;
      for (int j = 1; j < substring.length; j++) {
        if (substring.codeUnitAt(j) != substring.codeUnitAt(j - 1) - 1) {
          isDescending = false;
          break;
        }
      }
      
      if (isAscending || isDescending) {
        return true;
      }
    }
    
    return false;
  }

  /// Log validation errors for debugging
  static void _logValidationError(String method, dynamic error) {
    if (kDebugMode) {
      print('❌ ValidationService.$method error: $error');
    }
  }

  // Validation State Classes for Complex Forms

  /// Validation result with detailed feedback
  static ValidationResult validateAllSignUpFields({
    required String? fullName,
    required String? email,
    required String? password,
    String? confirmPassword,
  }) {
    final errors = <String, String>{};

    final fullNameError = validateFullName(fullName);
    if (fullNameError != null) {
      errors['fullName'] = fullNameError;
    }

    final emailError = validateEmail(email);
    if (emailError != null) {
      errors['email'] = emailError;
    }

    final passwordError = validatePassword(password);
    if (passwordError != null) {
      errors['password'] = passwordError;
    }

    if (confirmPassword != null) {
      final confirmPasswordError = validateConfirmPassword(confirmPassword, password);
      if (confirmPasswordError != null) {
        errors['confirmPassword'] = confirmPasswordError;
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Result class for comprehensive validation
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  const ValidationResult({
    required this.isValid,
    required this.errors,
  });

  /// Get error for specific field
  String? getError(String field) => errors[field];

  /// Check if specific field has error
  bool hasError(String field) => errors.containsKey(field);

  /// Get all error messages as a list
  List<String> get allErrors => errors.values.toList();

  /// Get first error message
  String? get firstError => errors.isEmpty ? null : errors.values.first;
}