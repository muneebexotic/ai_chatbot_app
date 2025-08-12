import 'package:flutter/material.dart';
import '../constants/subscription_constants.dart';

/// Utility class for subscription-related operations
class SubscriptionUtils {
  SubscriptionUtils._();

  /// Show success snack bar
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: SubscriptionConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show error snack bar
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: SubscriptionConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show info snack bar
  static void showInfoSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: SubscriptionConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Parse error message from exception
  static String parseErrorMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';
    
    String message = error.toString();
    
    // Remove common exception prefixes
    message = message.replaceFirst('Exception: ', '');
    message = message.replaceFirst('PurchaseException: ', '');
    message = message.replaceFirst('PaymentServiceException: ', '');
    
    // Handle common error patterns
    if (message.contains('user_cancelled')) {
      return SubscriptionConstants.purchaseCancelledMessage;
    }
    
    if (message.contains('network') || message.contains('connection')) {
      return SubscriptionConstants.networkErrorMessage;
    }
    
    if (message.contains('billing_unavailable')) {
      return 'Billing service is currently unavailable. Please try again later.';
    }
    
    if (message.contains('item_unavailable')) {
      return 'This subscription plan is currently unavailable.';
    }
    
    if (message.contains('item_already_owned')) {
      return 'You already have an active subscription.';
    }
    
    if (message.contains('authentication')) {
      return SubscriptionConstants.loginRequiredMessage;
    }
    
    // Fallback to original message if it's reasonable length
    if (message.length <= 100) {
      return message;
    }
    
    // Generic fallback
    return SubscriptionConstants.purchaseFailedMessage;
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: confirmColor != null
                ? TextButton.styleFrom(foregroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Format price for display
  static String formatPrice(double price, String currencyCode) {
    // Basic price formatting - you might want to use intl package for better formatting
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$${price.toStringAsFixed(2)}';
      case 'EUR':
        return '€${price.toStringAsFixed(2)}';
      case 'GBP':
        return '£${price.toStringAsFixed(2)}';
      case 'JPY':
        return '¥${price.round()}';
      case 'PKR':
        return 'Rs ${price.toStringAsFixed(0)}';
      default:
        return '${price.toStringAsFixed(2)} $currencyCode';
    }
  }

  /// Calculate discount percentage
  static double calculateDiscountPercentage(double originalPrice, double discountedPrice) {
    if (originalPrice == 0) return 0;
    return ((originalPrice - discountedPrice) / originalPrice) * 100;
  }

  /// Get readable subscription duration
  static String getSubscriptionDurationText(Duration duration) {
    if (duration.inDays >= 365) {
      final years = duration.inDays ~/ 365;
      return years == 1 ? '1 year' : '$years years';
    } else if (duration.inDays >= 30) {
      final months = duration.inDays ~/ 30;
      return months == 1 ? '1 month' : '$months months';
    } else if (duration.inDays >= 7) {
      final weeks = duration.inDays ~/ 7;
      return weeks == 1 ? '1 week' : '$weeks weeks';
    } else {
      return duration.inDays == 1 ? '1 day' : '${duration.inDays} days';
    }
  }

  /// Validate subscription status
  static bool isSubscriptionActive(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    return expiryDate.isAfter(DateTime.now());
  }

  /// Get days until expiry
  static int getDaysUntilExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return 0;
    final difference = expiryDate.difference(DateTime.now());
    return difference.inDays.clamp(0, double.infinity).toInt();
  }

  /// Check if subscription expires soon (within 7 days)
  static bool isSubscriptionExpiringSoon(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final daysUntilExpiry = getDaysUntilExpiry(expiryDate);
    return daysUntilExpiry <= 7 && daysUntilExpiry > 0;
  }
}