import 'package:cloud_firestore/cloud_firestore.dart';

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
  }) : dailyUsage = dailyUsage ?? {'messages': 0, 'images': 0, 'voice': 0},
       lastUsageReset = lastUsageReset ?? DateTime.now();

  // Convert Firestore document to AppUser
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      username: data['username'],
      photoUrl: data['photoUrl'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),

      // Subscription fields
      isPremium: data['isPremium'] ?? false,
      subscriptionType: data['subscriptionType'],
      subscriptionExpiryDate: data['subscriptionExpiryDate'] != null
          ? (data['subscriptionExpiryDate'] as Timestamp).toDate()
          : null,
      subscriptionStartDate: data['subscriptionStartDate'] != null
          ? (data['subscriptionStartDate'] as Timestamp).toDate()
          : null,

      // Usage tracking fields
      dailyUsage: Map<String, int>.from(
        data['dailyUsage'] ?? {'messages': 0, 'images': 0, 'voice': 0},
      ),
      lastUsageReset: data['lastUsageReset'] != null
          ? (data['lastUsageReset'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convert AppUser to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),

      // Subscription fields
      'isPremium': isPremium,
      'subscriptionType': subscriptionType,
      'subscriptionExpiryDate': subscriptionExpiryDate != null
          ? Timestamp.fromDate(subscriptionExpiryDate!)
          : null,
      'subscriptionStartDate': subscriptionStartDate != null
          ? Timestamp.fromDate(subscriptionStartDate!)
          : null,

      // Usage tracking fields
      'dailyUsage': dailyUsage,
      'lastUsageReset': Timestamp.fromDate(lastUsageReset),
    };
  }

  // Helper methods
  bool get hasActiveSubscription {
    if (!isPremium) return false;
    if (subscriptionExpiryDate == null) return false;
    return subscriptionExpiryDate!.isAfter(DateTime.now());
  }

  bool get isSubscriptionExpired {
    if (!isPremium) return false;
    if (subscriptionExpiryDate == null) return false;
    return subscriptionExpiryDate!.isBefore(DateTime.now());
  }

  int get daysUntilExpiry {
    if (subscriptionExpiryDate == null) return 0;
    return subscriptionExpiryDate!.difference(DateTime.now()).inDays;
  }

  String get subscriptionStatusText {
    if (!isPremium) return 'Free Plan';
    if (isSubscriptionExpired) return 'Expired';

    final type = subscriptionType == 'premium_monthly' ? 'Monthly' : 'Yearly';
    return 'Premium $type';
  }

  // Create a copy with updated fields
  AppUser copyWith({
    String? username,
    String? photoUrl,
    bool? isPremium,
    String? subscriptionType,
    DateTime? subscriptionExpiryDate,
    DateTime? subscriptionStartDate,
    Map<String, int>? dailyUsage,
    DateTime? lastUsageReset,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      isPremium: isPremium ?? this.isPremium,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      subscriptionExpiryDate:
          subscriptionExpiryDate ?? this.subscriptionExpiryDate,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      dailyUsage: dailyUsage ?? this.dailyUsage,
      lastUsageReset: lastUsageReset ?? this.lastUsageReset,
    );
  }

  // Check if user needs usage reset (new day)
  bool needsUsageReset() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastReset = DateTime(
      lastUsageReset.year,
      lastUsageReset.month,
      lastUsageReset.day,
    );
    return today.isAfter(lastReset);
  }

  // Get reset usage for new day
  AppUser resetDailyUsage() {
    return copyWith(
      dailyUsage: {'messages': 0, 'images': 0, 'voice': 0},
      lastUsageReset: DateTime.now(),
    );
  }

  // Increment usage counters
  AppUser incrementUsage(String type) {
    if (isPremium) return this; // Premium users have unlimited usage

    final newUsage = Map<String, int>.from(dailyUsage);
    newUsage[type] = (newUsage[type] ?? 0) + 1;

    return copyWith(dailyUsage: newUsage);
  }

  // Validation methods
  bool isValid() {
    return uid.isNotEmpty &&
        email.isNotEmpty &&
        email.contains('@') &&
        createdAt.isBefore(
          DateTime.now().add(Duration(minutes: 1)),
        ); // Allow small clock drift
  }

  String? validateSubscription() {
    if (isPremium) {
      if (subscriptionType == null) {
        return 'Premium user missing subscription type';
      }
      if (subscriptionExpiryDate == null) {
        return 'Premium user missing expiry date';
      }
      if (subscriptionExpiryDate!.isBefore(
        DateTime.now().subtract(Duration(days: 1)),
      )) {
        return 'Subscription expired more than 1 day ago';
      }
    }
    return null; // Valid
  }

  Map<String, int> validateUsage() {
    final validated = <String, int>{};
    
    // Ensure usage values are non-negative and reasonable
    validated['messages'] = (dailyUsage['messages'] ?? 0).clamp(0, 10000);
    validated['images'] = (dailyUsage['images'] ?? 0).clamp(0, 1000);
    validated['voice'] = (dailyUsage['voice'] ?? 0).clamp(0, 1000);
    
    return validated;
  }

   // Factory method with validation
  static AppUser? fromMapWithValidation(String uid, Map<String, dynamic> data) {
    try {
      final user = AppUser.fromMap(uid, data);
      
      if (!user.isValid()) {
        print('⚠️ Invalid user data for uid: $uid');
        return null;
      }
      
      final subscriptionError = user.validateSubscription();
      if (subscriptionError != null) {
        print('⚠️ Subscription validation error for $uid: $subscriptionError');
        // Could auto-fix here or return null based on severity
      }
      
      return user;
    } catch (e) {
      print('❌ Error creating AppUser from data: $e');
      return null;
    }
  }

  
}
