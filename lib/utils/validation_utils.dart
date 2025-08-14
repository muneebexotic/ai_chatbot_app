import 'package:flutter/foundation.dart';

/// Utility class for form validation
/// 
/// Centralized validation logic shared across login and signup screens
/// Features:
/// - Consistent validation rules
/// - Proper error messages
/// - Input sanitization
/// - Debug logging
class ValidationUtils {
  // Fixed email pattern - this was the source of your issue!
  static const String _emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const int _minPasswordLength = 6;
  static const int _minNameLength = 2;

  // Regex patterns for performance
  static final RegExp _emailRegex = RegExp(_emailPattern);
  static final RegExp _nameRegex = RegExp(r'^[a-zA-Z\s\u00C0-\u017F\u0100-\u024F]+$');
  static final RegExp _phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
  static final RegExp _passwordComplexityRegex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)');

  /// Validates email format
  static String? validateEmail(String? value) {
    try {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your email';
      }

      final sanitizedValue = value.trim();
      
      // Debug logging
      if (kDebugMode) {
        print('🔍 Validating email: "$sanitizedValue"');
      }

      // Check length limits
      if (sanitizedValue.length > 254) {
        return 'Email address is too long';
      }

      // Check email format
      if (!_emailRegex.hasMatch(sanitizedValue)) {
        if (kDebugMode) {
          print('❌ Email validation failed for: "$sanitizedValue"');
        }
        return 'Please enter a valid email';
      }

      // Additional basic validation
      if (!_isBasicEmailValid(sanitizedValue)) {
        return 'Please enter a valid email';
      }

      if (kDebugMode) {
        print('✅ Email validation passed for: "$sanitizedValue"');
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Email validation error: $e');
      }
      return 'Please enter a valid email';
    }
  }

  /// Basic email validation as fallback
  static bool _isBasicEmailValid(String email) {
    // Must contain exactly one @
    final atCount = email.split('@').length - 1;
    if (atCount != 1) return false;

    final parts = email.split('@');
    final localPart = parts[0];
    final domainPart = parts[1];

    // Local part must not be empty
    if (localPart.isEmpty) return false;

    // Domain part must contain at least one dot and not be empty
    if (domainPart.isEmpty || !domainPart.contains('.')) return false;

    // Domain must not start or end with dot
    if (domainPart.startsWith('.') || domainPart.endsWith('.')) return false;

    // Domain must have at least one character after the last dot
    final domainParts = domainPart.split('.');
    if (domainParts.last.length < 2) return false;

    return true;
  }

  /// Validates password strength
  static String? validatePassword(String? value, {int minLength = _minPasswordLength}) {
    try {
      if (value == null || value.isEmpty) {
        return 'Please enter your password';
      }

      if (value.length < minLength) {
        return 'Password must be at least $minLength characters';
      }

      if (value.length > 128) {
        return 'Password is too long (maximum 128 characters)';
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Password validation error: $e');
      }
      return 'Please enter a valid password';
    }
  }

  /// Validates password with complexity requirements (for signup)
  static String? validatePasswordComplex(String? value, {int minLength = _minPasswordLength}) {
    try {
      if (value == null || value.isEmpty) {
        return 'Please enter your password';
      }

      if (value.length < minLength) {
        return 'Password must be at least $minLength characters';
      }

      if (value.length > 128) {
        return 'Password is too long (maximum 128 characters)';
      }

      // Check complexity requirements for signup
      if (!_passwordComplexityRegex.hasMatch(value)) {
        return 'Password must contain letters and numbers';
      }

      // Check for common weak patterns
      if (_isWeakPassword(value)) {
        return 'Please choose a stronger password';
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Complex password validation error: $e');
      }
      return 'Please enter a valid password';
    }
  }

  /// Check for weak password patterns
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

    return false;
  }

  /// Validates required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName';
    }
    return null;
  }

  /// Validates phone number (basic validation)
  static String? validatePhoneNumber(String? value) {
    try {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your phone number';
      }

      final sanitizedValue = value.trim();
      
      if (!_phoneRegex.hasMatch(sanitizedValue)) {
        return 'Please enter a valid phone number';
      }

      // Check digit count (basic validation)
      final digitsOnly = sanitizedValue.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length < 10 || digitsOnly.length > 15) {
        return 'Please enter a valid phone number';
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Phone validation error: $e');
      }
      return 'Please enter a valid phone number';
    }
  }

  /// Validates name
  static String? validateName(String? value) {
    try {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your name';
      }

      final sanitizedValue = value.trim();
      
      if (sanitizedValue.length < _minNameLength) {
        return 'Name must be at least $_minNameLength characters';
      }

      // Check if contains only valid characters
      if (!_nameRegex.hasMatch(sanitizedValue)) {
        return 'Name can only contain letters and spaces';
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Name validation error: $e');
      }
      return 'Please enter a valid name';
    }
  }

  /// Validates full name (for signup)
  static String? validateFullName(String? value) {
    try {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your full name';
      }

      final sanitizedValue = value.trim();
      
      if (sanitizedValue.length < _minNameLength) {
        return 'Name must be at least $_minNameLength characters';
      }

      // Check if contains only valid characters
      if (!_nameRegex.hasMatch(sanitizedValue)) {
        return 'Name can only contain letters and spaces';
      }

      // Check for excessive whitespace
      if (sanitizedValue.contains(RegExp(r'\s{2,}'))) {
        return 'Please remove extra spaces from your name';
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Full name validation error: $e');
      }
      return 'Please enter a valid name';
    }
  }

  /// Validates confirm password
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Comprehensive validation for signup form
  static ValidationResult validateSignUpForm({
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

    final passwordError = validatePasswordComplex(password);
    if (passwordError != null) {
      errors['password'] = passwordError;
    }

    if (confirmPassword != null) {
      final confirmPasswordError = validateConfirmPassword(confirmPassword, password ?? '');
      if (confirmPasswordError != null) {
        errors['confirmPassword'] = confirmPasswordError;
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Comprehensive validation for login form
  static ValidationResult validateLoginForm({
    required String? email,
    required String? password,
  }) {
    final errors = <String, String>{};

    final emailError = validateEmail(email);
    if (emailError != null) {
      errors['email'] = emailError;
    }

    final passwordError = validatePassword(password);
    if (passwordError != null) {
      errors['password'] = passwordError;
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