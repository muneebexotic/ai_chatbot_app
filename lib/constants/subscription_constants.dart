/// Subscription-related constants
class SubscriptionConstants {
  SubscriptionConstants._();

  // Product IDs (MUST match your Google Play Console configuration exactly)
  static const String monthlySubscriptionId = 'premium_monthly';
  static const String yearlySubscriptionId = 'premium_yearly';

  // Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration purchaseTimeout = Duration(minutes: 2);

  // UI Constants
  static const Duration snackBarDuration = Duration(seconds: 4);
  static const Duration debounceDelay = Duration(milliseconds: 500);

  // Savings thresholds
  static const double minimumSavingsPercentage = 10.0;
  static const double maximumSavingsPercentage = 90.0;

  // Usage warning thresholds
  static const double usageWarningThreshold = 0.8; // Show warning at 80% usage
  static const int criticalRemainingMessages = 5; // Show critical warning

  // Feature limits for free users
  static const int freeMessagesPerDay = 10;
  static const int freeImagesPerDay = 3;
  static const int freeVoiceMinutesPerDay = 5;
  static const int maxConversationsForFreeUser = 5;

  // Premium feature identifiers
  static const List<String> premiumFeatures = [
    'unlimited_messages',
    'unlimited_images',
    'unlimited_voice',
    'all_personas',
    'priority_support',
    'advanced_ai_models',
    'conversation_export',
    'conversation_search',
  ];

  // Error messages
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String purchaseCancelledMessage = 'Purchase was cancelled.';
  static const String purchaseFailedMessage = 'Purchase failed. Please try again.';
  static const String restoreFailedMessage = 'Failed to restore purchases. Please try again.';
  static const String productsLoadFailedMessage = 'Unable to load subscription plans.';
  static const String loginRequiredMessage = 'Please log in to purchase subscription.';

  // Success messages
  static const String purchaseSuccessMessage = 'Purchase successful! Welcome to Premium!';
  static const String restoreSuccessMessage = 'Purchases restored successfully.';

  // Subscription terms
  static const String subscriptionTermsText = 
      'Subscription auto-renews unless cancelled. You can manage or cancel your '
      'subscription anytime in your Google Play or App Store account settings. '
      'Full terms and conditions apply.';

  // Privacy and terms URLs (replace with your actual URLs)
  static const String privacyPolicyUrl = 'https://yourapp.com/privacy';
  static const String termsOfServiceUrl = 'https://yourapp.com/terms';
  static const String supportUrl = 'https://yourapp.com/support';

  // Analytics event names
  static const String subscriptionViewedEvent = 'subscription_screen_viewed';
  static const String planSelectedEvent = 'subscription_plan_selected';
  static const String purchaseInitiatedEvent = 'purchase_initiated';
  static const String purchaseCompletedEvent = 'purchase_completed';
  static const String purchaseFailedEvent = 'purchase_failed';
  static const String restorePurchasesEvent = 'restore_purchases';
}