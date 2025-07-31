import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Your product IDs from Google Play Console
  static const String monthlySubscriptionId = 'monthly_subscription';
  static const Set<String> productIds = {monthlySubscriptionId};

  // Available products
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Purchase status
  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  // Callbacks
  Function(bool success, String message)? onPurchaseResult;
  Function(bool isSubscribed)? onSubscriptionStatusChanged;

  Future<void> initialize() async {
    // Check if in-app purchase is available
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      throw Exception('In-app purchases not available');
    }

    // Set up purchase listener
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => print('Purchase stream error: $error'),
    );

    // Load products
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.error != null) {
        throw Exception('Failed to load products: ${response.error!.message}');
      }

      _products = response.productDetails;
      
      if (_products.isEmpty) {
        throw Exception('No products found. Make sure products are set up in Google Play Console.');
      }
      
      print('Loaded ${_products.length} products');
      for (var product in _products) {
        print('Product: ${product.id} - ${product.title} - ${product.price}');
      }
    } catch (e) {
      print('Error loading products: $e');
      rethrow;
    }
  }

  Future<void> purchaseSubscription() async {
    try {
      ProductDetails? productDetails;
      
      // Find the product details
      for (var product in _products) {
        if (product.id == monthlySubscriptionId) {
          productDetails = product;
          break;
        }
      }

      if (productDetails == null) {
        onPurchaseResult?.call(false, 'Product not found');
        return;
      }

      _purchasePending = true;

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // For subscriptions, use buyNonConsumable
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
    } catch (e) {
      _purchasePending = false;
      onPurchaseResult?.call(false, 'Purchase failed: $e');
      print('Purchase error: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _handlePurchase(purchaseDetails);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    _purchasePending = false;

    if (purchaseDetails.status == PurchaseStatus.purchased) {
      // Purchase successful
      await _verifyPurchase(purchaseDetails);
      onPurchaseResult?.call(true, 'Subscription activated successfully!');
      onSubscriptionStatusChanged?.call(true);
      
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      // Purchase failed
      print('Purchase failed: ${purchaseDetails.error}');
      onPurchaseResult?.call(false, 'Purchase failed: ${purchaseDetails.error?.message ?? 'Unknown error'}');
      
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      // User canceled
      onPurchaseResult?.call(false, 'Purchase canceled');
    }

    // Always complete the purchase
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Here you would typically verify the purchase with your backend server
    // For now, we'll just mark it as verified locally
    
    // You should:
    // 1. Send purchase token to your server
    // 2. Verify with Google Play Developer API
    // 3. Grant premium features to user
    
    print('Purchase verified: ${purchaseDetails.productID}');
    
    // Save subscription status locally (you might want to use SharedPreferences)
    // await _saveSubscriptionStatus(true);
  }

  Future<bool> checkSubscriptionStatus() async {
    try {
      // Check if user has active subscription
      await _inAppPurchase.restorePurchases();
      
      // This is simplified - in a real app, you'd check with your server
      // or use Google Play Developer API to verify subscription status
      
      return false; // Return actual status
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}