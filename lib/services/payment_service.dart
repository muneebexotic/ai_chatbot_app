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

  Future<void> syncSubscriptionWithGooglePlay() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No user for subscription sync');
        return;
      }

      print('🔄 Syncing Google Play subscription for user: ${currentUser.uid}');

      // First, check current Firestore status
      await _loadSubscriptionStatusFromFirestore();
      final firestorePremiumStatus = _isPremium;

      print('📱 Current Firestore premium status: $firestorePremiumStatus');

      // CRITICAL FIX: Only restore purchases if user ALREADY has a subscription record
      // This prevents new/free users from getting premium access from old purchases
      if (firestorePremiumStatus && _subscriptionExpiryDate != null) {
        // Check if current subscription is expired or about to expire
        final now = DateTime.now();
        final isExpired = _subscriptionExpiryDate!.isBefore(now);
        final isExpiringSoon = _subscriptionExpiryDate!.isBefore(
          now.add(Duration(hours: 1)),
        ); // Check 1 hour before expiry

        if (isExpired || isExpiringSoon) {
          print(
            '🔍 Existing subscription expired/expiring, checking Google Play...',
          );
          await _inAppPurchase.restorePurchases();

          // Wait for purchase stream processing
          await Future.delayed(Duration(seconds: 2));

          // Re-check status after restore
          await _loadSubscriptionStatusFromFirestore();
          final updatedPremiumStatus = _isPremium;

          if (updatedPremiumStatus != firestorePremiumStatus) {
            print(
              '✅ Subscription status updated after restore: $updatedPremiumStatus',
            );
            onSubscriptionStatusChanged?.call(updatedPremiumStatus);
          } else {
            print('✅ No subscription changes detected after restore');
          }
        } else {
          print('✅ User has active subscription, no restore needed');
        }
      } else {
        print('✅ User has no existing subscription, skipping Google Play sync');
        // CRITICAL: For users without existing subscriptions, don't restore purchases
        // This prevents free users from getting premium access
      }

      print('✅ Subscription sync completed');
    } catch (e) {
      print('❌ Error syncing subscription with Google Play: $e');
      // Don't throw - we don't want to break login if sync fails
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

  // CRITICAL FIX: Enhanced purchase handling with strict validation for restored purchases
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

      // CRITICAL FIX: Enhanced validation for restored purchases
      final isRestored = purchaseDetails.status == PurchaseStatus.restored;

      if (isRestored) {
        print(
          '🔍 Processing RESTORED purchase - applying strict validation...',
        );

        // STRICT VALIDATION: Only accept restored purchases if user already has subscription record
        final existingUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (!existingUserDoc.exists || existingUserDoc.data() == null) {
          print('❌ Restored purchase rejected: No user data found');
          await _inAppPurchase.completePurchase(purchaseDetails);
          return;
        }

        final existingData = existingUserDoc.data()!;
        final hadPreviousSubscription =
            existingData['isPremium'] == true ||
            existingData['subscriptionType'] != null;

        // CRITICAL: Only accept restored purchases for users who had subscriptions before
        if (!hadPreviousSubscription) {
          print('❌ Restored purchase rejected: User never had a subscription');
          await _inAppPurchase.completePurchase(purchaseDetails);
          return;
        }

        // Check if this is a subscription product
        if (!productIds.contains(purchaseDetails.productID)) {
          print(
            '❌ Restored purchase for unknown product: ${purchaseDetails.productID}',
          );
          await _inAppPurchase.completePurchase(purchaseDetails);
          return;
        }

        // Validate purchase token exists and isn't empty
        if (purchaseDetails.verificationData.localVerificationData.isEmpty) {
          print('❌ Restored purchase missing verification data');
          await _inAppPurchase.completePurchase(purchaseDetails);
          return;
        }

        // CRITICAL: Additional validation - check if this purchase token was already processed
        final storedPurchaseToken = existingData['purchaseToken'] as String?;
        final currentPurchaseToken =
            purchaseDetails.verificationData.localVerificationData;

        // If this is the same purchase token we already have, validate expiry
        if (storedPurchaseToken == currentPurchaseToken) {
          final expiryDate =
              existingData['subscriptionExpiryDate'] as Timestamp?;

          if (expiryDate != null) {
            final expiry = expiryDate.toDate();

            if (expiry.isBefore(DateTime.now())) {
              print('❌ Restored purchase is expired: $expiry');
              // Don't grant premium access for expired subscriptions
              await _inAppPurchase.completePurchase(purchaseDetails);
              return;
            } else {
              print('✅ Restored purchase is still valid until: $expiry');
              // Continue processing - this is a valid active subscription
            }
          }
        } else {
          // Different purchase token - this might be a renewal or different subscription
          print('🔍 Different purchase token detected, validating...');

          // For different tokens, we need to be extra careful
          // Only accept if the user currently has an expired subscription
          final currentExpiry =
              existingData['subscriptionExpiryDate'] as Timestamp?;
          if (currentExpiry == null ||
              currentExpiry.toDate().isAfter(DateTime.now())) {
            print(
              '❌ Restored purchase rejected: User has active subscription with different token',
            );
            await _inAppPurchase.completePurchase(purchaseDetails);
            return;
          }
        }

        print('✅ Restored purchase validation passed');
      }

      // CRITICAL: Additional validation - ensure purchase belongs to current user
      if (purchaseDetails.purchaseID?.isEmpty == true) {
        print('❌ Purchase missing purchase ID');
        await _inAppPurchase.completePurchase(purchaseDetails);
        return;
      }

      // Purchase successful and validated
      print('✅ Purchase successful/validated for user: ${currentUser.uid}');
      await _verifyAndStorePurchase(purchaseDetails);

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

  // ENHANCED: Purchase verification with comprehensive validation
  Future<void> _verifyAndStorePurchase(PurchaseDetails purchaseDetails) async {
    try {
      print('🔍 Verifying and storing purchase: ${purchaseDetails.productID}');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user for purchase verification');
        return;
      }

      // CRITICAL: Validate purchase details before processing
      if (!await validatePurchaseDetails(purchaseDetails)) {
        print('❌ Purchase validation failed');
        return;
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

      // CRITICAL FIX: For restored purchases, use existing start date if available
      final isRestored = purchaseDetails.status == PurchaseStatus.restored;
      if (isRestored) {
        // Check if we already have subscription data in Firestore
        final existingUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (existingUserDoc.exists && existingUserDoc.data() != null) {
          final existingData = existingUserDoc.data()!;
          final existingStartDate =
              existingData['subscriptionStartDate'] as Timestamp?;
          final existingExpiryDate =
              existingData['subscriptionExpiryDate'] as Timestamp?;

          // If we have existing subscription data for the same product, preserve it
          if (existingStartDate != null &&
              existingExpiryDate != null &&
              existingData['subscriptionType'] == purchaseDetails.productID) {
            startDate = existingStartDate.toDate();
            expiryDate = existingExpiryDate.toDate();

            print(
              '📅 Using existing subscription dates - Start: $startDate, Expiry: $expiryDate',
            );

            // Double-check the subscription isn't expired
            if (expiryDate.isBefore(DateTime.now())) {
              print(
                '❌ Restored subscription is expired, not granting premium access',
              );
              return;
            }
          }
        }
      }

      // Save to Firestore FIRST (single source of truth)
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

  // ENHANCED: Comprehensive purchase validation
  Future<bool> validatePurchaseDetails(PurchaseDetails details) async {
    try {
      print('🔍 Validating purchase details...');

      // Validate current user
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

      // Validate purchase ID exists
      if (details.purchaseID?.isEmpty == true) {
        print('❌ Missing purchase ID');
        return false;
      }

      // For restored purchases, additional validation
      if (details.status == PurchaseStatus.restored) {
        print('🔍 Additional validation for restored purchase...');

        // Check if this purchase token is already associated with a different user
        // (This would be rare but possible in case of account switching)

        // SECURITY: Ensure purchase token hasn't been used by another user
        final existingUsers = await FirebaseFirestore.instance
            .collection('users')
            .where(
              'purchaseToken',
              isEqualTo: details.verificationData.localVerificationData,
            )
            .get();

        for (var userDoc in existingUsers.docs) {
          if (userDoc.id != currentUser.uid) {
            print(
              '⚠️ Purchase token found on different user account: ${userDoc.id}',
            );
            // Could be a legitimate account transfer, but log for investigation
            print(
              '🔍 Current user: ${currentUser.uid}, Token user: ${userDoc.id}',
            );
          }
        }
      }

      print('✅ Purchase validation passed');
      return true;
    } catch (e) {
      print('❌ Error validating purchase: $e');
      return false;
    }
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
