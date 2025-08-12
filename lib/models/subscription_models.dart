import 'package:in_app_purchase/in_app_purchase.dart';

/// Enumeration for subscription plan types
enum SubscriptionPlan {
  monthly,
  yearly,
}

/// Extension for subscription plan utilities
extension SubscriptionPlanExtension on SubscriptionPlan {
  String get displayName {
    switch (this) {
      case SubscriptionPlan.monthly:
        return 'Monthly Pro';
      case SubscriptionPlan.yearly:
        return 'Yearly Pro';
    }
  }

  String get periodText {
    switch (this) {
      case SubscriptionPlan.monthly:
        return 'per month';
      case SubscriptionPlan.yearly:
        return 'per year';
    }
  }

  String get shortPeriod {
    switch (this) {
      case SubscriptionPlan.monthly:
        return 'month';
      case SubscriptionPlan.yearly:
        return 'year';
    }
  }

  Duration get billingCycle {
    switch (this) {
      case SubscriptionPlan.monthly:
        return const Duration(days: 30);
      case SubscriptionPlan.yearly:
        return const Duration(days: 365);
    }
  }
}

/// Model representing subscription product information
class SubscriptionProduct {
  final String id;
  final String title;
  final String description;
  final String price;
  final String currencyCode;
  final double rawPrice;
  final SubscriptionPlan plan;
  final ProductDetails? productDetails;

  const SubscriptionProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.rawPrice,
    required this.plan,
    this.productDetails,
  });

  factory SubscriptionProduct.fromProductDetails(
    ProductDetails product,
    SubscriptionPlan plan,
  ) {
    return SubscriptionProduct(
      id: product.id,
      title: product.title,
      description: product.description,
      price: product.price,
      currencyCode: product.currencyCode,
      rawPrice: product.rawPrice,
      plan: plan,
      productDetails: product,
    );
  }

  /// Calculate savings percentage compared to another product
  double calculateSavingsPercentage(SubscriptionProduct compareWith) {
    if (compareWith.rawPrice == 0) return 0;
    
    // Calculate monthly equivalent prices
    final thisMonthlyPrice = plan == SubscriptionPlan.monthly 
        ? rawPrice 
        : rawPrice / 12;
    final compareMonthlyPrice = compareWith.plan == SubscriptionPlan.monthly 
        ? compareWith.rawPrice 
        : compareWith.rawPrice / 12;
    
    if (compareMonthlyPrice == 0) return 0;
    
    final savings = (compareMonthlyPrice - thisMonthlyPrice) / compareMonthlyPrice;
    return (savings * 100).clamp(0, 100);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionProduct &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SubscriptionProduct(id: $id, plan: $plan, price: $price)';
}

/// Model representing subscription benefits/features
class SubscriptionFeature {
  final String title;
  final String description;
  final String iconName;
  final bool isPremiumOnly;

  const SubscriptionFeature({
    required this.title,
    required this.description,
    required this.iconName,
    this.isPremiumOnly = true,
  });

  static const List<SubscriptionFeature> premiumFeatures = [
    SubscriptionFeature(
      title: 'Unlimited Messages',
      description: 'Send unlimited messages without daily limits',
      iconName: 'message_outlined',
    ),
    SubscriptionFeature(
      title: 'All Personas',
      description: 'Access to all AI personas and personalities',
      iconName: 'psychology_outlined',
    ),
    SubscriptionFeature(
      title: 'Unlimited Images',
      description: 'Generate and analyze unlimited images',
      iconName: 'image_outlined',
    ),
    SubscriptionFeature(
      title: 'Unlimited Voice',
      description: 'Voice conversations without restrictions',
      iconName: 'mic_outlined',
    ),
    SubscriptionFeature(
      title: 'Priority Support',
      description: 'Get priority customer support and assistance',
      iconName: 'support_agent_outlined',
    ),
  ];
}

/// Custom exception for purchase-related errors
class PurchaseException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const PurchaseException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'PurchaseException: $message';
}

/// Model for subscription state
class SubscriptionState {
  final List<SubscriptionProduct> products;
  final SubscriptionPlan selectedPlan;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const SubscriptionState({
    this.products = const [],
    this.selectedPlan = SubscriptionPlan.monthly,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  SubscriptionState copyWith({
    List<SubscriptionProduct>? products,
    SubscriptionPlan? selectedPlan,
    bool? isLoading,
    bool? isInitialized,
    String? error,
  }) {
    return SubscriptionState(
      products: products ?? this.products,
      selectedPlan: selectedPlan ?? this.selectedPlan,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error ?? this.error,
    );
  }

  SubscriptionProduct? get selectedProduct {
    try {
      return products.firstWhere((product) => product.plan == selectedPlan);
    } catch (e) {
      return null;
    }
  }

  SubscriptionProduct? get monthlyProduct {
    try {
      return products.firstWhere((product) => product.plan == SubscriptionPlan.monthly);
    } catch (e) {
      return null;
    }
  }

  SubscriptionProduct? get yearlyProduct {
    try {
      return products.firstWhere((product) => product.plan == SubscriptionPlan.yearly);
    } catch (e) {
      return null;
    }
  }

  bool get hasAllProducts => monthlyProduct != null && yearlyProduct != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionState &&
          runtimeType == other.runtimeType &&
          products == other.products &&
          selectedPlan == other.selectedPlan &&
          isLoading == other.isLoading &&
          isInitialized == other.isInitialized &&
          error == other.error;

  @override
  int get hashCode =>
      products.hashCode ^
      selectedPlan.hashCode ^
      isLoading.hashCode ^
      isInitialized.hashCode ^
      error.hashCode;
}