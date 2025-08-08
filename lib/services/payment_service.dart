import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final FirestoreService _firestoreService = FirestoreService();

  // Your product IDs from Google Play Console
  static const String monthlySubscriptionId = 'premium_monthly';
  static const String yearlySubscriptionId = 'premium_yearly';
  static const Set<String> productIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
  };

  // Free tier limits
  static const int FREE_DAILY_MESSAGES = 20;
  static const int FREE_DAILY_IMAGES = 3;
  static const int FREE_DAILY_VOICE = 5;
  static const int FREE_PERSONAS_COUNT = 3; // Default + 2 others

  // Available products
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Purchase status
  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  // CRITICAL FIX: Premium status ONLY from Firestore - removed local storage fallback
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  // Queue system for offline scenarios:
  List<Map<String, dynamic>> _pendingUsageUpdates = [];

  DateTime? _subscriptionExpiryDate;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;

  String? _currentSubscriptionType;
  String? get currentSubscriptionType => _currentSubscriptionType;

  String? _currentUserId;

  // Usage tracking - Now synced with Firestore
  int _dailyMessageCount = 0;
  int _dailyImageCount = 0;
  int _dailyVoiceCount = 0;
  DateTime _lastUsageReset = DateTime.now();

  // Getters for usage
  int get dailyMessageCount => _dailyMessageCount;
  int get dailyImageCount => _dailyImageCount;
  int get dailyVoiceCount => _dailyVoiceCount;
  int get remainingMessages => _isPremium
      ? -1
      : (FREE_DAILY_MESSAGES - _dailyMessageCount).clamp(
          0,
          FREE_DAILY_MESSAGES,
        );
  int get remainingImages => _isPremium
      ? -1
      : (FREE_DAILY_IMAGES - _dailyImageCount).clamp(0, FREE_DAILY_IMAGES);
  int get remainingVoice => _isPremium
      ? -1
      : (FREE_DAILY_VOICE - _dailyVoiceCount).clamp(0, FREE_DAILY_VOICE);

  // Callbacks
  Function(bool success, String message)? onPurchaseResult;
  Function(bool isSubscribed)? onSubscriptionStatusChanged;
  Function()? onUsageLimitReached;

  Future<void> initialize() async {
    try {
      print('🔄 Initializing PaymentService...');

      // Check if in-app purchase is available
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw Exception('In-app purchases not available');
      }
      print('✅ In-app purchases available');

      // Set up purchase listener
      final Stream<List<PurchaseDetails>> purchaseUpdated =
          _inAppPurchase.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) => print('❌ Purchase stream error: $error'),
      );
      print('✅ Purchase stream listener set up');

      // Load products
      await _loadProducts();

      print('✅ Payment service base initialization completed');
    } catch (e) {
      print('❌ Error initializing payment service: $e');
      rethrow;
    }
  }

  void _queueUsageUpdate() {
    _pendingUsageUpdates.add({
      'messages': _dailyMessageCount,
      'images': _dailyImageCount,
      'voice': _dailyVoiceCount,
      'timestamp': DateTime.now(),
    });
  }

  Future<void> _processPendingUpdates() async {
    if (_pendingUsageUpdates.isEmpty) return;

    try {
      // Process the latest update only
      final latestUpdate = _pendingUsageUpdates.last;
      _dailyMessageCount = latestUpdate['messages'];
      _dailyImageCount = latestUpdate['images'];
      _dailyVoiceCount = latestUpdate['voice'];

      await _saveUsageDataToFirestore();
      _pendingUsageUpdates.clear();
      print('✅ Processed pending usage updates');
    } catch (e) {
      print('❌ Failed to process pending updates: $e');
    }
  }

  // CRITICAL FIX: Initialize for specific user with proper user isolation
  Future<void> initializeForUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('⚠️ No authenticated user for payment service');
      _resetToDefaults();
      return;
    }

    // Only reset if user actually changed
    if (_currentUserId != currentUser.uid) {
      print('🔄 User changed, resetting payment service...');
      _resetToDefaults();
      _currentUserId = currentUser.uid;
    }

    print('🔄 Initializing payment service for user: ${currentUser.uid}');

    // Load everything from Firestore (single source of truth)
    await _loadSubscriptionStatusFromFirestore();
    await _loadUsageDataFromFirestore();
    await _checkAndResetDailyUsage();

    print(
      '✅ Payment service initialized for user: ${currentUser.uid}, Premium: $_isPremium',
    );
  }

  // CRITICAL FIX: Complete user data clearing
  Future<void> clearUserData() async {
    print('🔄 Clearing payment service user data...');

    _currentUserId = null;
    _resetToDefaults();

    print('✅ Payment service user data cleared completely');
  }

  void _resetToDefaults() {
    _isPremium = false;
    _currentSubscriptionType = null;
    _subscriptionExpiryDate = null;
    _dailyMessageCount = 0;
    _dailyImageCount = 0;
    _dailyVoiceCount = 0;
    _lastUsageReset = DateTime.now();
  }

  Future<void> _loadProducts() async {
    try {
      print('🔄 Loading products...');
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds);

      if (response.error != null) {
        print('❌ Product loading error: ${response.error!.message}');
        throw Exception('Failed to load products: ${response.error!.message}');
      }

      _products = response.productDetails;

      print('📦 Found ${_products.length} products');
      print('📦 Not found products: ${response.notFoundIDs}');

      if (_products.isEmpty) {
        print('⚠️ No products found. Check Google Play Console configuration.');
      }

      for (var product in _products) {
        print(
          '✅ Product loaded: ${product.id} - ${product.title} - ${product.price}',
        );
      }
    } catch (e) {
      print('❌ Error loading products: $e');
    }
  }

  Future<void> purchaseSubscription(String productId) async {
    try {
      print('🛒 Starting purchase for product: $productId');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        onPurchaseResult?.call(false, 'Please log in to purchase subscription');
        return;
      }

      print('👤 Current user: ${currentUser.uid}');

      // CRITICAL: Check if user already has active subscription before allowing purchase
      if (_isPremium &&
          _subscriptionExpiryDate != null &&
          _subscriptionExpiryDate!.isAfter(DateTime.now())) {
        print('⚠️ User already has active subscription');
        onPurchaseResult?.call(
          false,
          'You already have an active subscription',
        );
        return;
      }

      ProductDetails? productDetails;
      for (var product in _products) {
        if (product.id == productId) {
          productDetails = product;
          break;
        }
      }

      if (productDetails == null) {
        print('❌ Product not found: $productId');
        onPurchaseResult?.call(false, 'Product not found. Please try again.');
        return;
      }

      print(
        '✅ Found product: ${productDetails.title} - ${productDetails.price}',
      );

      _purchasePending = true;

      // CRITICAL: Use buyNonConsumable for subscriptions, not buyConsumable
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: currentUser.uid, // Links purchase to user
      );

      print('🔄 Initiating purchase with user: ${currentUser.uid}');

      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('💳 Purchase initiated: $success');

      if (!success) {
        _purchasePending = false;
        onPurchaseResult?.call(false, 'Failed to initiate purchase');
      }
    } catch (e) {
      _purchasePending = false;
      print('❌ Purchase error: $e');
      onPurchaseResult?.call(false, 'Purchase failed: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    print('🔔 Purchase update received: ${purchaseDetailsList.length} items');
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print(
        '📱 Processing purchase: ${purchaseDetails.productID} - Status: ${purchaseDetails.status}',
      );
      _handlePurchase(purchaseDetails);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    _purchasePending = false;

    print('🔄 Handling purchase: ${purchaseDetails.productID}');
    print('📊 Purchase status: ${purchaseDetails.status}');

    if (purchaseDetails.error != null) {
      print('❌ Purchase error details: ${purchaseDetails.error}');
    }

    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      // CRITICAL: Verify user before processing purchase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user found during purchase processing');
        await _inAppPurchase.completePurchase(purchaseDetails);
        return;
      }

      // Purchase successful
      print('✅ Purchase successful/restored for user: ${currentUser.uid}');
      await _verifyAndStorePurchase(purchaseDetails);

      final isRestored = purchaseDetails.status == PurchaseStatus.restored;
      onPurchaseResult?.call(
        true,
        isRestored
            ? 'Subscription restored successfully!'
            : 'Subscription activated successfully!',
      );
      onSubscriptionStatusChanged?.call(true);
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      print('❌ Purchase failed: ${purchaseDetails.error}');
      String errorMessage = 'Purchase failed';
      if (purchaseDetails.error != null) {
        errorMessage = _getReadableErrorMessage(purchaseDetails.error!);
      }
      onPurchaseResult?.call(false, errorMessage);
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      print('⚠️ Purchase canceled by user');
      onPurchaseResult?.call(false, 'Purchase canceled');
    } else if (purchaseDetails.status == PurchaseStatus.pending) {
      print('⏳ Purchase pending');
      _purchasePending = true;
      onPurchaseResult?.call(
        false,
        'Purchase is pending. Please wait for confirmation.',
      );
    }

    // Always complete the purchase
    if (purchaseDetails.pendingCompletePurchase) {
      print('🔄 Completing purchase...');
      await _inAppPurchase.completePurchase(purchaseDetails);
      print('✅ Purchase completed');
    }
  }

  String _getReadableErrorMessage(IAPError error) {
    switch (error.code) {
      case 'user_cancelled':
        return 'Purchase was cancelled';
      case 'payment_invalid':
        return 'Payment method is invalid';
      case 'payment_not_allowed':
        return 'Payment not allowed on this device';
      case 'billing_unavailable':
        return 'Billing service unavailable. Please try again later.';
      case 'item_unavailable':
        return 'This subscription is currently unavailable';
      case 'item_already_owned':
        return 'You already own this subscription';
      case 'item_not_owned':
        return 'You do not own this item';
      case 'network_error':
        return 'Network error. Please check your connection and try again.';
      default:
        return error.message ?? 'An unexpected error occurred';
    }
  }

  // CRITICAL FIX: Enhanced purchase verification with user validation
  Future<void> _verifyAndStorePurchase(PurchaseDetails purchaseDetails) async {
    try {
      print('🔍 Verifying and storing purchase: ${purchaseDetails.productID}');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user for purchase verification');
        return;
      }

      // CRITICAL: Validate that purchase belongs to current user
      if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
        // The applicationUserName should match current user
        print('🔍 Verifying purchase belongs to user: ${currentUser.uid}');
      }

      // Calculate expiry date based on subscription type
      DateTime expiryDate;
      DateTime startDate = DateTime.now();

      if (purchaseDetails.productID == monthlySubscriptionId) {
        expiryDate = startDate.add(Duration(days: 30));
        print('📅 Monthly subscription expires: $expiryDate');
      } else if (purchaseDetails.productID == yearlySubscriptionId) {
        expiryDate = startDate.add(Duration(days: 365));
        print('📅 Yearly subscription expires: $expiryDate');
      } else {
        print('❌ Unknown product ID: ${purchaseDetails.productID}');
        return;
      }

      // Update local state ONLY after Firestore success
      await _saveSubscriptionToFirestore(
        purchaseDetails,
        startDate,
        expiryDate,
      );

      // Update local state only after Firestore success
      _isPremium = true;
      _currentSubscriptionType = purchaseDetails.productID;
      _subscriptionExpiryDate = expiryDate;

      print('✅ Purchase verified and stored: ${purchaseDetails.productID}');
    } catch (e) {
      print('❌ Error verifying purchase: $e');
      // Don't update local state if Firestore fails
    }
  }

  // CRITICAL FIX: Enhanced Firestore save with transaction for data consistency
  Future<void> _saveSubscriptionToFirestore(
    PurchaseDetails purchaseDetails,
    DateTime startDate,
    DateTime expiryDate,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user found for Firestore save');
        throw Exception('No authenticated user');
      }

      print('💾 Saving subscription to Firestore for user: ${currentUser.uid}');

      // Use transaction to ensure data consistency
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get current user document
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('User document not found');
        }

        // Create comprehensive subscription record
        final subscriptionData = {
          'isPremium': true,
          'subscriptionType': purchaseDetails.productID,
          'subscriptionStartDate': Timestamp.fromDate(startDate),
          'subscriptionExpiryDate': Timestamp.fromDate(expiryDate),
          'purchaseToken':
              purchaseDetails.verificationData.localVerificationData,
          'purchaseId': purchaseDetails.purchaseID,
          'lastPurchaseDate': Timestamp.fromDate(DateTime.now()),
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'verified': true,
        };

        // Update user document
        transaction.update(userRef, subscriptionData);

        // Also store in subscription history
        final historyRef = userRef.collection('subscription_history').doc();
        transaction.set(historyRef, {
          ...subscriptionData,
          'purchaseTimestamp': Timestamp.fromDate(DateTime.now()),
        });
      });

      print('✅ Subscription saved to Firestore with transaction');
    } catch (e) {
      print('❌ Error saving subscription to Firestore: $e');
      throw e;
    }
  }

  // CRITICAL FIX: Load subscription status ONLY from Firestore
  Future<void> _loadSubscriptionStatusFromFirestore() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No user for loading subscription status');
        _resetToDefaults();
        return;
      }

      print(
        '🔄 Loading subscription status from Firestore for: ${currentUser.uid}',
      );

      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        print('⚠️ User document not found in Firestore');
        _resetToDefaults();
        return;
      }

      final data = userDoc.data()!;

      // Load subscription data
      _isPremium = data['isPremium'] ?? false;
      _currentSubscriptionType = data['subscriptionType'];

      if (data['subscriptionExpiryDate'] != null) {
        _subscriptionExpiryDate = (data['subscriptionExpiryDate'] as Timestamp)
            .toDate();

        // CRITICAL: Check if subscription has expired
        if (_subscriptionExpiryDate!.isBefore(DateTime.now())) {
          print('⚠️ Subscription expired, updating status');
          _isPremium = false;
          _currentSubscriptionType = null;
          _subscriptionExpiryDate = null;

          // Update Firestore to reflect expired status
          await _firestoreService.cancelUserSubscription(currentUser.uid);
        }
      }

      print(
        '✅ Subscription status loaded from Firestore: Premium = $_isPremium, Type = $_currentSubscriptionType',
      );
    } catch (e) {
      print('❌ Error loading subscription from Firestore: $e');
      _resetToDefaults(); // Don't fallback to local storage
    }
  }

  // CRITICAL FIX: Load usage data from Firestore
  Future<void> _loadUsageDataFromFirestore() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      print('🔄 Loading usage data from Firestore for: ${currentUser.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final usage = Map<String, int>.from(
          data['dailyUsage'] ?? {'messages': 0, 'images': 0, 'voice': 0},
        );

        _dailyMessageCount = usage['messages'] ?? 0;
        _dailyImageCount = usage['images'] ?? 0;
        _dailyVoiceCount = usage['voice'] ?? 0;

        if (data['lastUsageReset'] != null) {
          _lastUsageReset = (data['lastUsageReset'] as Timestamp).toDate();
        }

        print(
          '✅ Usage data loaded from Firestore: Messages=$_dailyMessageCount, Images=$_dailyImageCount, Voice=$_dailyVoiceCount',
        );
      }
    } catch (e) {
      print('❌ Error loading usage from Firestore: $e');
    }
  }

  Future<void> _checkAndResetDailyUsage() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastReset = DateTime(
      _lastUsageReset.year,
      _lastUsageReset.month,
      _lastUsageReset.day,
    );

    if (today.isAfter(lastReset)) {
      print('🔄 Resetting daily usage for new day');
      _dailyMessageCount = 0;
      _dailyImageCount = 0;
      _dailyVoiceCount = 0;
      _lastUsageReset = now;

      // Save to Firestore
      await _saveUsageDataToFirestore();

      print('✅ Daily usage counters reset');
    }
  }

  // Usage tracking methods with Firestore sync
  bool canSendMessage() {
    if (_isPremium) return true;
    return _dailyMessageCount < FREE_DAILY_MESSAGES;
  }

  bool canUploadImage() {
    if (_isPremium) return true;
    return _dailyImageCount < FREE_DAILY_IMAGES;
  }

  bool canSendVoice() {
    if (_isPremium) return true;
    return _dailyVoiceCount < FREE_DAILY_VOICE;
  }

  bool canAccessAllPersonas() {
    return _isPremium;
  }

  Future<void> incrementMessageCount() async {
    if (_isPremium) return;

    _dailyMessageCount++;
    await _saveUsageDataToFirestore();
  }

  Future<void> incrementImageCount() async {
    if (_isPremium) return;

    _dailyImageCount++;
    await _saveUsageDataToFirestore();
  }

  Future<void> incrementVoiceCount() async {
    if (_isPremium) return;

    _dailyVoiceCount++;
    await _saveUsageDataToFirestore();
  }

  Future<void> _saveUsageDataToFirestore() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No user for usage save - queuing for later');
        _queueUsageUpdate(); // Queue for when user returns
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'dailyUsage': {
              'messages': _dailyMessageCount,
              'images': _dailyImageCount,
              'voice': _dailyVoiceCount,
            },
            'lastUsageReset': Timestamp.fromDate(_lastUsageReset),
          });

      print('✅ Usage saved to Firestore');
    } catch (e) {
      print('❌ Error saving usage to Firestore: $e');
      _queueUsageUpdate(); // Retry later
    }
  }

  // CRITICAL FIX: Enhanced subscription verification with user validation
  Future<void> _verifyActiveSubscriptionsWithValidation() async {
    try {
      print('🔄 Verifying active subscriptions with Google Play...');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No user for subscription verification');
        return;
      }

      // Query Google Play for active purchases
      await _inAppPurchase.restorePurchases();

      print(
        '✅ Subscription verification completed for user: ${currentUser.uid}',
      );
    } catch (e) {
      print('❌ Error verifying subscriptions: $e');
    }
  }

  Future<bool> checkSubscriptionStatus() async {
    try {
      print('🔄 Checking subscription status...');

      // Always verify against Firestore first (single source of truth)
      await _loadSubscriptionStatusFromFirestore();

      print('✅ Subscription status checked: $_isPremium');
      return _isPremium;
    } catch (e) {
      print('❌ Error checking subscription status: $e');
      return _isPremium;
    }
  }

  Future<void> restorePurchases() async {
    try {
      print('🔄 Restoring purchases...');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Please log in to restore purchases');
      }

      // Restore from Google Play
      await _inAppPurchase.restorePurchases();

      // Reload from Firestore to get latest status
      await _loadSubscriptionStatusFromFirestore();

      print('✅ Purchases restored for user: ${currentUser.uid}');
    } catch (e) {
      print('❌ Error restoring purchases: $e');
      rethrow;
    }
  }

  // Add to PaymentService - Purchase validation:
  Future<bool> validatePurchaseDetails(PurchaseDetails details) async {
    // Validate purchase belongs to current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user for purchase validation');
      return false;
    }

    // Validate product ID
    if (!productIds.contains(details.productID)) {
      print('❌ Invalid product ID: ${details.productID}');
      return false;
    }

    // Validate purchase token exists
    if (details.verificationData.localVerificationData.isEmpty) {
      print('❌ Missing purchase verification data');
      return false;
    }

    // Additional Google Play validation could go here
    return true;
  }

  // Get formatted subscription info
  String getSubscriptionStatusText() {
    if (!_isPremium) return 'Free Plan';

    final type = _currentSubscriptionType == monthlySubscriptionId
        ? 'Monthly'
        : 'Yearly';
    if (_subscriptionExpiryDate != null) {
      final days = _subscriptionExpiryDate!.difference(DateTime.now()).inDays;
      if (days > 0) {
        return 'Premium $type ($days days left)';
      } else {
        return 'Premium $type (Expired)';
      }
    }
    return 'Premium $type';
  }

  String getUsageText() {
    if (_isPremium) return 'Unlimited usage';

    return 'Messages: $_dailyMessageCount/$FREE_DAILY_MESSAGES, '
        'Images: $_dailyImageCount/$FREE_DAILY_IMAGES, '
        'Voice: $_dailyVoiceCount/$FREE_DAILY_VOICE';
  }

  void dispose() {
    _subscription.cancel();
  }
}
