import 'package:flutter/foundation.dart';

import '../constants/subscription_constants.dart';
import '../models/subscription_models.dart';
import '../services/payment_service.dart';

/// Extensions for PaymentService to support subscription features
extension PaymentServiceSubscriptionExtensions on PaymentService {
  
  /// Get monthly subscription product ID
  static String get monthlySubscriptionId => SubscriptionConstants.monthlySubscriptionId;
  
  /// Get yearly subscription product ID  
  static String get yearlySubscriptionId => SubscriptionConstants.yearlySubscriptionId;

  /// Get all subscription product IDs
  static List<String> get allSubscriptionIds => [
    monthlySubscriptionId,
    yearlySubscriptionId,
  ];

  /// Check if a product ID is a subscription
  bool isSubscriptionProduct(String productId) {
    return PaymentServiceSubscriptionExtensions.allSubscriptionIds.contains(productId);
  }

  /// Get subscription plan type from product ID
  SubscriptionPlan? getSubscriptionPlanFromProductId(String productId) {
    switch (productId) {
      case SubscriptionConstants.monthlySubscriptionId:
        return SubscriptionPlan.monthly;
      case SubscriptionConstants.yearlySubscriptionId:
        return SubscriptionPlan.yearly;
      default:
        return null;
    }
  }

  /// Purchase subscription with enhanced error handling
  Future<void> purchaseSubscriptionWithRetry(
    String productId, {
    int maxRetries = SubscriptionConstants.maxRetryAttempts,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        await purchaseSubscription(productId);
        return; // Success
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempts++;
        
        if (attempts < maxRetries) {
          await Future.delayed(SubscriptionConstants.retryDelay);
          debugPrint('Purchase attempt $attempts failed, retrying...');
        }
      }
    }

    // If we get here, all attempts failed
    throw lastException ?? const PurchaseException('Purchase failed after multiple attempts');
  }

  /// Restore purchases with enhanced error handling
  Future<void> restorePurchasesWithRetry({
    int maxRetries = SubscriptionConstants.maxRetryAttempts,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        await restorePurchases();
        return; // Success
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempts++;
        
        if (attempts < maxRetries) {
          await Future.delayed(SubscriptionConstants.retryDelay);
          debugPrint('Restore attempt $attempts failed, retrying...');
        }
      }
    }

    // If we get here, all attempts failed
    throw lastException ?? const PurchaseException('Restore failed after multiple attempts');
  }
}

/// Subscription analytics helper
class SubscriptionAnalytics {
  SubscriptionAnalytics._();

  /// Track subscription screen view
  static void trackSubscriptionViewed() {
    // Implement your analytics tracking here
    debugPrint('Analytics: ${SubscriptionConstants.subscriptionViewedEvent}');
  }

  /// Track plan selection
  static void trackPlanSelected(SubscriptionPlan plan) {
    // Implement your analytics tracking here
    debugPrint('Analytics: ${SubscriptionConstants.planSelectedEvent} - ${plan.name}');
  }

  /// Track purchase initiation
  static void trackPurchaseInitiated(SubscriptionProduct product) {
    // Implement your analytics tracking here
    debugPrint('Analytics: ${SubscriptionConstants.purchaseInitiatedEvent} - ${product.id}');
  }

  /// Track purchase completion
  static void trackPurchaseCompleted(SubscriptionProduct product) {
    // Implement your analytics tracking here
    debugPrint('Analytics: ${SubscriptionConstants.purchaseCompletedEvent} - ${product.id}');
  }

  /// Track purchase failure
  static void trackPurchaseFailed(String productId, String error) {
    // Implement your analytics tracking here
    debugPrint('Analytics: ${SubscriptionConstants.purchaseFailedEvent} - $productId: $error');
  }

  /// Track restore purchases
  static void trackRestorePurchases() {
    // Implement your analytics tracking here
    debugPrint('Analytics: ${SubscriptionConstants.restorePurchasesEvent}');
  }
}