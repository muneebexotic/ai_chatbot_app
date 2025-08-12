import 'package:flutter/foundation.dart';
import '../models/subscription_models.dart';
import '../services/payment_service.dart';
import '../constants/subscription_constants.dart';

class SubscriptionProvider extends ChangeNotifier {
  final PaymentService _paymentService;
  
  // State management
  SubscriptionState _state = const SubscriptionState();
  
  SubscriptionProvider(this._paymentService) {
    _setupPaymentServiceCallbacks();
  }

  // Getters
  SubscriptionState get state => _state;
  List<SubscriptionProduct> get products => _state.products;
  SubscriptionPlan get selectedPlan => _state.selectedPlan;
  bool get isLoading => _state.isLoading;
  bool get isInitialized => _state.isInitialized;
  String? get error => _state.error;
  
  SubscriptionProduct? get selectedProduct => _state.selectedProduct;
  SubscriptionProduct? get monthlyProduct => _state.monthlyProduct;
  SubscriptionProduct? get yearlyProduct => _state.yearlyProduct;
  bool get hasAllProducts => _state.hasAllProducts;

  /// Initialize the subscription provider
  Future<void> initialize() async {
    if (_state.isInitialized) return;
    
    _updateState(_state.copyWith(isLoading: true, error: null));
    
    try {
      // Initialize PaymentService if not already done
      if (!_paymentService.isInitialized) {
        await _paymentService.initialize();
      }
      
      // Load products from PaymentService
      await _loadProducts();
      
      _updateState(_state.copyWith(
        isInitialized: true,
        isLoading: false,
        error: null,
      ));
      
      debugPrint('✅ SubscriptionProvider initialized successfully');
    } catch (e) {
      debugPrint('❌ SubscriptionProvider initialization failed: $e');
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Failed to load subscription plans: ${e.toString()}',
        isInitialized: false,
      ));
    }
  }

  /// Load products from PaymentService
  Future<void> _loadProducts() async {
    try {
      // Get subscription products from PaymentService
      final subscriptionProducts = _paymentService.getSubscriptionProducts();
      
      if (subscriptionProducts.isEmpty) {
        throw Exception('No subscription products available');
      }
      
      _updateState(_state.copyWith(
        products: subscriptionProducts,
        error: null,
      ));
      
      debugPrint('✅ Loaded ${subscriptionProducts.length} subscription products');
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
      throw Exception('Unable to load subscription plans');
    }
  }

  /// Refresh products from store
  Future<void> refreshProducts() async {
    _updateState(_state.copyWith(isLoading: true, error: null));
    
    try {
      // Reinitialize PaymentService to refresh products
      await _paymentService.initialize();
      await _loadProducts();
      
      _updateState(_state.copyWith(
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      debugPrint('❌ Error refreshing products: $e');
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Failed to refresh products: ${e.toString()}',
      ));
    }
  }

  /// Select a subscription plan
  void selectPlan(SubscriptionPlan plan) {
    if (_state.selectedPlan == plan) return;
    
    _updateState(_state.copyWith(selectedPlan: plan));
    debugPrint('📋 Selected plan: ${plan.displayName}');
  }

  /// Purchase the selected subscription
  Future<void> purchaseSubscription() async {
    final selectedProduct = _state.selectedProduct;
    if (selectedProduct == null) {
      throw Exception('No product selected');
    }
    
    _updateState(_state.copyWith(isLoading: true));
    
    try {
      await _paymentService.purchaseSubscription(selectedProduct.id);
      // Success handling is done through payment service callbacks
    } catch (e) {
      debugPrint('❌ Purchase failed: $e');
      _updateState(_state.copyWith(isLoading: false));
      rethrow;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    _updateState(_state.copyWith(isLoading: true));
    
    try {
      await _paymentService.restorePurchases();
      _updateState(_state.copyWith(isLoading: false));
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      _updateState(_state.copyWith(isLoading: false));
      rethrow;
    }
  }

  /// Get yearly savings text
  String getYearlySavingsText() {
    final monthlyProduct = _state.monthlyProduct;
    final yearlyProduct = _state.yearlyProduct;
    
    if (monthlyProduct == null || yearlyProduct == null) {
      return '';
    }
    
    final savings = yearlyProduct.calculateSavingsPercentage(monthlyProduct);
    
    if (savings >= SubscriptionConstants.minimumSavingsPercentage) {
      return 'Save ${savings.round()}%';
    }
    
    return '';
  }

  /// Setup payment service callbacks
  void _setupPaymentServiceCallbacks() {
    _paymentService.onPurchaseResult = (success, message) {
      _updateState(_state.copyWith(isLoading: false));
      
      if (success) {
        debugPrint('✅ Purchase successful: $message');
      } else {
        debugPrint('❌ Purchase failed: $message');
      }
    };
    
    _paymentService.onSubscriptionStatusChanged = (isSubscribed) {
      debugPrint('🔔 Subscription status changed: $isSubscribed');
      // You might want to refresh products or update UI here
    };
  }

  /// Update state and notify listeners
  void _updateState(SubscriptionState newState) {
    if (_state == newState) return;
    
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up callbacks
    _paymentService.onPurchaseResult = null;
    _paymentService.onSubscriptionStatusChanged = null;
    super.dispose();
  }
}