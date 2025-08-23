import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced AppUser model with improved validation, timezone handling, and error management
class AppUser {
  final String uid;
  final String email;
  final String? username;
  final String? photoUrl;
  final DateTime createdAt;

  // Subscription fields
  final bool isPremium;
  final String? subscriptionType; // 'premium_monthly' or 'premium_yearly'
  final DateTime? subscriptionExpiryDate;
  final DateTime? subscriptionStartDate;

  // Usage tracking fields
  final Map<String, int> dailyUsage;
  final DateTime lastUsageReset;

  // Enhanced metadata fields
  final DateTime lastUpdated;
  final String? deviceInfo;
  final String? appVersion;

  // Configuration constants
  static const int MAX_USERNAME_LENGTH = 50;
  static const int MAX_DAILY_MESSAGES = 20;
  static const int MAX_DAILY_IMAGES = 3;
  static const int MAX_DAILY_VOICE = 5;
  static const int MAX_USAGE_VALUE = 100000;
  
  // Valid subscription types
  static const Set<String> VALID_SUBSCRIPTION_TYPES = {
    'premium_monthly',
    'premium_yearly'
  };

  AppUser({
    required this.uid,
    required this.email,
    this.username,
    this.photoUrl,
    required this.createdAt,
    this.isPremium = false,
    this.subscriptionType,
    this.subscriptionExpiryDate,
    this.subscriptionStartDate,
    Map<String, int>? dailyUsage,
    DateTime? lastUsageReset,
    DateTime? lastUpdated,
    this.deviceInfo,
    this.appVersion,
  }) : 
    dailyUsage = _validateUsageMap(dailyUsage),
    lastUsageReset = lastUsageReset ?? _getTodayStart(),
    lastUpdated = lastUpdated ?? DateTime.now();

  /// Create validated usage map with proper defaults
  static Map<String, int> _validateUsageMap(Map<String, int>? usage) {
    final validatedUsage = <String, int>{};
    final defaultUsage = {'messages': 0, 'images': 0, 'voice': 0};
    
    if (usage != null) {
      for (final entry in usage.entries) {
        validatedUsage[entry.key] = entry.value.clamp(0, MAX_USAGE_VALUE);
      }
    }
    
    // Ensure all required keys exist
    for (final key in defaultUsage.keys) {
      validatedUsage.putIfAbsent(key, () => defaultUsage[key]!);
    }
    
    return validatedUsage;
  }

  /// Get start of today in UTC for consistent timezone handling
  static DateTime _getTodayStart() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Enhanced factory method with comprehensive validation
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    try {
      // Validate required fields
      if (uid.isEmpty) {
        throw AppUserException('UID cannot be empty');
      }

      final email = data['email'] as String? ?? '';
      if (email.isEmpty || !_isValidEmail(email)) {
        throw AppUserException('Invalid email address');
      }

      // Parse dates safely
      final createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now();
      final lastUsageReset = _parseTimestamp(data['lastUsageReset']) ?? _getTodayStart();
      final lastUpdated = _parseTimestamp(data['lastUpdated']) ?? DateTime.now();
      
      // Parse subscription dates
      DateTime? subscriptionExpiryDate;
      DateTime? subscriptionStartDate;
      
      if (data['subscriptionExpiryDate'] != null) {
        subscriptionExpiryDate = _parseTimestamp(data['subscriptionExpiryDate']);
      }
      
      if (data['subscriptionStartDate'] != null) {
        subscriptionStartDate = _parseTimestamp(data['subscriptionStartDate']);
      }

      // Validate subscription consistency
      final isPremium = data['isPremium'] as bool? ?? false;
      final subscriptionType = data['subscriptionType'] as String?;
      
      if (isPremium) {
        if (subscriptionType == null || !VALID_SUBSCRIPTION_TYPES.contains(subscriptionType)) {
          print('⚠️ Premium user has invalid subscription type: $subscriptionType');
        }
        if (subscriptionExpiryDate == null) {
          print('⚠️ Premium user missing expiry date');
        }
      }

      return AppUser(
        uid: uid,
        email: email,
        username: _sanitizeUsername(data['username'] as String?),
        photoUrl: _sanitizeUrl(data['photoUrl'] as String?),
        createdAt: createdAt,
        isPremium: isPremium,
        subscriptionType: subscriptionType,
        subscriptionExpiryDate: subscriptionExpiryDate,
        subscriptionStartDate: subscriptionStartDate,
        dailyUsage: _parseUsageMap(data['dailyUsage']),
        lastUsageReset: lastUsageReset,
        lastUpdated: lastUpdated,
        deviceInfo: data['deviceInfo'] as String?,
        appVersion: data['appVersion'] as String?,
      );
    } catch (e) {
      throw AppUserException('Failed to create AppUser from data: $e');
    }
  }

  /// Factory method with comprehensive validation and error handling
  static AppUser? fromMapWithValidation(String uid, Map<String, dynamic> data) {
    try {
      final user = AppUser.fromMap(uid, data);
      
      // Run comprehensive validation
      final validationErrors = user._runFullValidation();
      if (validationErrors.isNotEmpty) {
        print('⚠️ User validation errors for $uid: ${validationErrors.join(', ')}');
        
        // Return null for critical errors, user for warnings
        final hasCriticalError = validationErrors.any((error) => 
          error.contains('email') || 
          error.contains('uid') ||
          error.contains('created'));
          
        if (hasCriticalError) {
          return null;
        }
      }
      
      return user;
    } catch (e) {
      print('❌ Error creating AppUser with validation: $e');
      return null;
    }
  }

  /// Parse timestamp safely with multiple format support
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    
    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print('⚠️ Failed to parse timestamp: $timestamp, error: $e');
    }
    
    return null;
  }

  /// Parse usage map safely
  static Map<String, int> _parseUsageMap(dynamic usageData) {
    if (usageData is Map<String, dynamic>) {
      final usage = <String, int>{};
      for (final entry in usageData.entries) {
        if (entry.value is int) {
          usage[entry.key] = (entry.value as int).clamp(0, MAX_USAGE_VALUE);
        } else if (entry.value is num) {
          usage[entry.key] = (entry.value as num).toInt().clamp(0, MAX_USAGE_VALUE);
        }
      }
      return _validateUsageMap(usage);
    }
    
    return _validateUsageMap(null);
  }

  /// Sanitize username input
  static String? _sanitizeUsername(String? username) {
    if (username == null || username.trim().isEmpty) return null;
    
    String sanitized = username
        .trim()
        .replaceAll(RegExp(r'''[<>"']'''), '') 
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
    
    if (sanitized.length > MAX_USERNAME_LENGTH) {
      sanitized = sanitized.substring(0, MAX_USERNAME_LENGTH);
    }
    
    return sanitized.isNotEmpty ? sanitized : null;
  }

  /// Sanitize URL input
  static String? _sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    
    final sanitized = url.trim();
    
    // Basic URL validation
    if (sanitized.startsWith('http://') || 
        sanitized.startsWith('https://') ||
        sanitized.startsWith('data:image/')) {
      return sanitized.length <= 2048 ? sanitized : null;
    }
    
    return null;
  }

  /// Validate email format
  static bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Convert AppUser to Firestore document with enhanced data integrity
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      
      // Subscription fields with validation
      'isPremium': isPremium,
      'subscriptionType': subscriptionType,
      'subscriptionExpiryDate': subscriptionExpiryDate != null
          ? Timestamp.fromDate(subscriptionExpiryDate!)
          : null,
      'subscriptionStartDate': subscriptionStartDate != null
          ? Timestamp.fromDate(subscriptionStartDate!)
          : null,
      
      // Usage tracking fields
      'dailyUsage': Map<String, int>.from(dailyUsage),
      'lastUsageReset': Timestamp.fromDate(lastUsageReset),
      
      // Enhanced metadata
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'deviceInfo': deviceInfo,
      'appVersion': appVersion,
      
      // Data integrity fields
      'dataVersion': 2, // For future migrations
      'validatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  // SUBSCRIPTION HELPER METHODS

  /// Check if user has active subscription with proper timezone handling
  bool get hasActiveSubscription {
    if (!isPremium) return false;
    if (subscriptionExpiryDate == null) return false;
    
    // Use UTC for consistent comparison
    final now = DateTime.now().toUtc();
    final expiryUtc = subscriptionExpiryDate!.toUtc();
    
    return expiryUtc.isAfter(now);
  }

  /// Check if subscription is expired
  bool get isSubscriptionExpired {
    if (!isPremium) return false;
    return !hasActiveSubscription;
  }

  /// Get days until expiry with proper timezone handling
  int get daysUntilExpiry {
    if (subscriptionExpiryDate == null) return 0;
    
    final now = DateTime.now().toUtc();
    final expiryUtc = subscriptionExpiryDate!.toUtc();
    final difference = expiryUtc.difference(now);
    
    return difference.inDays;
  }

  /// Get hours until expiry for more precise calculations
  int get hoursUntilExpiry {
    if (subscriptionExpiryDate == null) return 0;
    
    final now = DateTime.now().toUtc();
    final expiryUtc = subscriptionExpiryDate!.toUtc();
    final difference = expiryUtc.difference(now);
    
    return difference.inHours;
  }

  /// Get subscription status text with enhanced information
  String get subscriptionStatusText {
    if (!isPremium) return 'Free Plan';
    if (isSubscriptionExpired) return 'Subscription Expired';

    final type = subscriptionType == 'premium_monthly' ? 'Monthly' : 'Yearly';
    final days = daysUntilExpiry;
    
    if (days <= 0) {
      return 'Premium $type (Expires Today)';
    } else if (days <= 7) {
      return 'Premium $type (Expires in $days days)';
    } else {
      return 'Premium $type';
    }
  }

  /// Check if subscription needs renewal warning
  bool get needsRenewalWarning {
    if (!hasActiveSubscription) return false;
    return daysUntilExpiry <= 7; // Warn 7 days before expiry
  }

  // USAGE HELPER METHODS

  /// Check if user needs usage reset with proper timezone handling
  bool needsUsageReset() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    
    final resetUtc = lastUsageReset.toUtc();
    final resetDay = DateTime.utc(resetUtc.year, resetUtc.month, resetUtc.day);
    
    return today.isAfter(resetDay);
  }

  /// Get reset usage for new day
  AppUser resetDailyUsage() {
    return copyWith(
      dailyUsage: {'messages': 0, 'images': 0, 'voice': 0},
      lastUsageReset: _getTodayStart(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Increment usage counters with validation
  AppUser incrementUsage(String type, {int amount = 1}) {
    if (hasActiveSubscription) return this; // Premium users have unlimited usage
    
    if (amount <= 0 || amount > 100) {
      print('⚠️ Invalid usage increment amount: $amount');
      return this;
    }

    final newUsage = Map<String, int>.from(dailyUsage);
    final currentValue = newUsage[type] ?? 0;
    final newValue = (currentValue + amount).clamp(0, MAX_USAGE_VALUE);
    
    newUsage[type] = newValue;

    return copyWith(
      dailyUsage: newUsage,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get usage percentage for a specific type
  double getUsagePercentage(String type) {
    if (hasActiveSubscription) return 0.0; // Unlimited for premium users
    
    final current = dailyUsage[type] ?? 0;
    final limit = _getUsageLimit(type);
    
    return limit > 0 ? (current / limit * 100).clamp(0.0, 100.0) : 0.0;
  }

  /// Get usage limit for a specific type
  int _getUsageLimit(String type) {
    switch (type) {
      case 'messages': return MAX_DAILY_MESSAGES;
      case 'images': return MAX_DAILY_IMAGES;
      case 'voice': return MAX_DAILY_VOICE;
      default: return 0;
    }
  }

  /// Check if usage limit is reached for a specific type
  bool isUsageLimitReached(String type) {
    if (hasActiveSubscription) return false;
    
    final current = dailyUsage[type] ?? 0;
    final limit = _getUsageLimit(type);
    
    return current >= limit;
  }

  /// Get remaining usage for a specific type
  int getRemainingUsage(String type) {
    if (hasActiveSubscription) return -1; // Unlimited
    
    final current = dailyUsage[type] ?? 0;
    final limit = _getUsageLimit(type);
    
    return (limit - current).clamp(0, limit);
  }

  // VALIDATION METHODS

  /// Comprehensive validation with detailed error reporting
  List<String> _runFullValidation() {
    final errors = <String>[];
    
    // Basic field validation
    if (uid.isEmpty) errors.add('Empty UID');
    if (email.isEmpty) errors.add('Empty email');
    if (!_isValidEmail(email)) errors.add('Invalid email format');
    
    // Date validation
    final now = DateTime.now();
    if (createdAt.isAfter(now.add(Duration(minutes: 5)))) {
      errors.add('Created date is in the future');
    }
    
    if (lastUsageReset.isAfter(now.add(Duration(minutes: 5)))) {
      errors.add('Last usage reset is in the future');
    }
    
    // Subscription validation
    final subscriptionValidation = validateSubscription();
    if (subscriptionValidation != null) {
      errors.add(subscriptionValidation);
    }
    
    // Usage validation
    final usageErrors = _validateUsageValues();
    errors.addAll(usageErrors);
    
    return errors;
  }

  /// Basic validation for critical fields
  bool isValid() {
    return uid.isNotEmpty &&
           email.isNotEmpty &&
           _isValidEmail(email) &&
           createdAt.isBefore(DateTime.now().add(Duration(minutes: 5)));
  }

  /// Validate subscription consistency and logic
  String? validateSubscription() {
    if (isPremium) {
      if (subscriptionType == null) {
        return 'Premium user missing subscription type';
      }
      
      if (!VALID_SUBSCRIPTION_TYPES.contains(subscriptionType)) {
        return 'Invalid subscription type: $subscriptionType';
      }
      
      if (subscriptionExpiryDate == null) {
        return 'Premium user missing expiry date';
      }
      
      if (subscriptionStartDate == null) {
        return 'Premium user missing start date';
      }
      
      // Check date consistency
      if (subscriptionStartDate!.isAfter(subscriptionExpiryDate!)) {
        return 'Subscription start date is after expiry date';
      }
      
      // Check if subscription expired more than grace period
      if (subscriptionExpiryDate!.isBefore(
        DateTime.now().subtract(Duration(days: 30))
      )) {
        return 'Subscription expired more than 30 days ago';
      }
    } else {
      // Non-premium user should not have subscription data
      if (subscriptionType != null) {
        return 'Non-premium user has subscription type';
      }
    }
    
    return null; // Valid
  }

  /// Validate usage values and detect anomalies
  List<String> _validateUsageValues() {
    final errors = <String>[];
    
    for (final entry in dailyUsage.entries) {
      final type = entry.key;
      final value = entry.value;
      
      if (value < 0) {
        errors.add('Negative usage value for $type: $value');
      }
      
      if (value > MAX_USAGE_VALUE) {
        errors.add('Usage value too high for $type: $value');
      }
      
      // Check for suspicious usage patterns
      final limit = _getUsageLimit(type);
      if (!hasActiveSubscription && value > limit * 2) {
        errors.add('Suspicious usage for free user $type: $value (limit: $limit)');
      }
    }
    
    return errors;
  }

  /// Validate and sanitize usage data
  Map<String, int> validateUsage() {
    final validated = <String, int>{};
    
    for (final entry in dailyUsage.entries) {
      final sanitizedValue = entry.value.clamp(0, MAX_USAGE_VALUE);
      validated[entry.key] = sanitizedValue;
      
      if (sanitizedValue != entry.value) {
        print('⚠️ Sanitized usage value for ${entry.key}: ${entry.value} -> $sanitizedValue');
      }
    }
    
    // Ensure all required keys exist
    validated.putIfAbsent('messages', () => 0);
    validated.putIfAbsent('images', () => 0);
    validated.putIfAbsent('voice', () => 0);
    
    return validated;
  }

  // UTILITY METHODS

  /// Create a copy with updated fields and automatic lastUpdated timestamp
  AppUser copyWith({
    String? username,
    String? photoUrl,
    bool? isPremium,
    String? subscriptionType,
    DateTime? subscriptionExpiryDate,
    DateTime? subscriptionStartDate,
    Map<String, int>? dailyUsage,
    DateTime? lastUsageReset,
    DateTime? lastUpdated,
    String? deviceInfo,
    String? appVersion,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      username: _sanitizeUsername(username) ?? this.username,
      photoUrl: _sanitizeUrl(photoUrl) ?? this.photoUrl,
      createdAt: createdAt,
      isPremium: isPremium ?? this.isPremium,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      subscriptionExpiryDate: subscriptionExpiryDate ?? this.subscriptionExpiryDate,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      dailyUsage: _validateUsageMap(dailyUsage),
      lastUsageReset: lastUsageReset ?? this.lastUsageReset,
      lastUpdated: lastUpdated ?? DateTime.now(),
      deviceInfo: deviceInfo ?? this.deviceInfo,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  /// Get user summary for debugging and analytics
  Map<String, dynamic> getSummary() {
    return {
      'uid': uid,
      'email': email,
      'isPremium': isPremium,
      'subscriptionType': subscriptionType,
      'daysUntilExpiry': daysUntilExpiry,
      'dailyUsage': dailyUsage,
      'needsReset': needsUsageReset(),
      'isValid': isValid(),
      'hasActiveSubscription': hasActiveSubscription,
      'createdDaysAgo': DateTime.now().difference(createdAt).inDays,
    };
  }

  /// Compare with another user for equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AppUser &&
           other.uid == uid &&
           other.email == email &&
           other.username == username &&
           other.photoUrl == photoUrl &&
           other.isPremium == isPremium &&
           other.subscriptionType == subscriptionType;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      email,
      username,
      photoUrl,
      isPremium,
      subscriptionType,
    );
  }

  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, isPremium: $isPremium, '
           'subscriptionType: $subscriptionType, valid: ${isValid()})';
  }
}

/// Custom exception for AppUser-related errors
class AppUserException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppUserException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'AppUserException [$code]: $message';
    }
    return 'AppUserException: $message';
  }
}