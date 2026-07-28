import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../constants/subscription_constants.dart';
import '../models/subscription_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_chatbot_app/core/logging/log.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Core services
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Stream subscriptions for proper cleanup
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  /// Always null since Milestone 2 — see [_setupAuthStateListener]. Retained
  /// only so the existing cancel-on-dispose path stays intact.
  StreamSubscription<void>? _authSubscription;

  // Product configurations
  static const String monthlySubscriptionId =
      SubscriptionConstants.monthlySubscriptionId;
  static const String yearlySubscriptionId =
      SubscriptionConstants.yearlySubscriptionId;
  static const Set<String> productIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
  };

  // Free tier limits
  static const int freeDailyMessages =
      SubscriptionConstants.freeMessagesPerDay;
  static const int freeDailyImages = SubscriptionConstants.freeImagesPerDay;
  static const int freeDailyVoice =
      SubscriptionConstants.freeVoiceMinutesPerDay;
  static const int freePersonasCount =
      SubscriptionConstants.maxConversationsForFreeUser;

  // State management
  List<ProductDetails> _products = [];
  bool _purchasePending = false;
  bool _isInitialized = false;
  String? _currentUserId;

  // Entitlement, read from the server and never written here (F2).
  bool _isPremium = false;
  DateTime? _subscriptionExpiryDate;
  String? _currentSubscriptionType;

  // Display-only counters. Superseded by ChatUsage from the gateway.
  Map<String, int> _dailyUsage = {'messages': 0, 'images': 0, 'voice': 0};
  DateTime _lastUsageReset = DateTime.now();

  // Cache management
  DateTime? _lastCacheUpdate;
  static const Duration cacheDuration = Duration(minutes: 5);

  // Offline queue for usage updates
  final List<Map<String, dynamic>> _pendingUsageUpdates = [];
  Timer? _syncTimer;

  // Public getters
  List<ProductDetails> get products => List.unmodifiable(_products);
  bool get purchasePending => _purchasePending;
  bool get isPremium => _isPremium;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  String? get currentSubscriptionType => _currentSubscriptionType;
  bool get isInitialized => _isInitialized;

  // Usage getters
  int get dailyMessageCount => _dailyUsage['messages'] ?? 0;
  int get dailyImageCount => _dailyUsage['images'] ?? 0;
  int get dailyVoiceCount => _dailyUsage['voice'] ?? 0;

  int get remainingMessages => _isPremium
      ? -1
      : (freeDailyMessages - dailyMessageCount).clamp(0, freeDailyMessages);
  int get remainingImages => _isPremium
      ? -1
      : (freeDailyImages - dailyImageCount).clamp(0, freeDailyImages);
  int get remainingVoice => _isPremium
      ? -1
      : (freeDailyVoice - dailyVoiceCount).clamp(0, freeDailyVoice);

  // Callback functions
  Function(bool success, String message)? onPurchaseResult;
  Function(bool isSubscribed)? onSubscriptionStatusChanged;
  Function()? onUsageLimitReached;

  /// Get subscription product by plan type
  SubscriptionProduct? getProductByPlan(SubscriptionPlan plan) {
    final productId = plan == SubscriptionPlan.monthly
        ? monthlySubscriptionId
        : yearlySubscriptionId;

    final productDetails = _products
        .where((p) => p.id == productId)
        .firstOrNull;

    if (productDetails != null) {
      return SubscriptionProduct.fromProductDetails(productDetails, plan);
    }

    return null;
  }

  /// Get all subscription products as SubscriptionProduct models
  List<SubscriptionProduct> getSubscriptionProducts() {
    final subscriptionProducts = <SubscriptionProduct>[];

    for (final product in _products) {
      SubscriptionPlan? plan;
      if (product.id == monthlySubscriptionId) {
        plan = SubscriptionPlan.monthly;
      } else if (product.id == yearlySubscriptionId) {
        plan = SubscriptionPlan.yearly;
      }

      if (plan != null) {
        subscriptionProducts.add(
          SubscriptionProduct.fromProductDetails(product, plan),
        );
      }
    }

    return subscriptionProducts;
  }

  /// Initialize the payment service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Log.d('Initializing PaymentService...');

      // Check in-app purchase availability
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw PaymentServiceException(
          'In-app purchases not available on this device',
        );
      }

      // Load products
      await _loadProducts();

      // Set up purchase stream
      await _setupPurchaseStream();

      // Set up auth state listener
      _setupAuthStateListener();

      // Start periodic sync timer
      _startPeriodicSync();

      _isInitialized = true;
      Log.d('PaymentService initialized successfully');
    } catch (e) {
      Log.d('PaymentService initialization failed: $e');
      rethrow;
    }
  }

  /// Set up purchase stream listener
  Future<void> _setupPurchaseStream() async {
    await _purchaseSubscription?.cancel();

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        Log.d('Purchase stream error: $error');
        _purchasePending = false;
      },
      onDone: () => Log.d('Purchase stream closed'),
    );
  }

  /// No longer listens for authentication changes.
  ///
  /// This used to subscribe to `FirebaseAuth.authStateChanges()`. Nothing
  /// signs into Firebase any more (Milestone 2), so that stream can never
  /// emit — the subscription would sit there looking like user-scoping while
  /// doing nothing at all, which is worse than no mechanism because it reads
  /// as one.
  ///
  /// `AuthProvider` now drives this class explicitly, calling
  /// [initializeForUser] on sign-in and [clearUserData] on sign-out. Being
  /// pushed to rather than listening also means there is exactly one place
  /// that decides what "the current user changed" means.
  void _setupAuthStateListener() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }


  /// Initialize for a specific user
  Future<void> initializeForUser(String userId) async {
    try {
      Log.d('Initializing for user: $userId');

      if (_currentUserId == userId && _isCacheValid()) {
        Log.d('Using cached data for user: $userId');
        return;
      }

      _currentUserId = userId;
      await _loadUserData();
      await _checkAndResetDailyUsage();
      await _processPendingUpdates();

      // Sync with Google Play if needed
      if (_isPremium && _shouldSyncWithGooglePlay()) {
        await _syncWithGooglePlay();
      }

      Log.d('User initialization completed for: $userId');
    } catch (e) {
      Log.d('Error initializing for user: $e');
      throw PaymentServiceException('Failed to initialize user data: $e');
    }
  }

  /// Clear all user data
  Future<void> clearUserData() async {
    try {
      Log.d('Clearing user data...');

      _currentUserId = null;
      _isPremium = false;
      _subscriptionExpiryDate = null;
      _currentSubscriptionType = null;
      _dailyUsage = {'messages': 0, 'images': 0, 'voice': 0};
      _lastUsageReset = DateTime.now();
      _lastCacheUpdate = null;
      _pendingUsageUpdates.clear();

      Log.d('User data cleared');
    } catch (e) {
      Log.d('Error clearing user data: $e');
    }
  }

  /// Load products from store
  Future<void> _loadProducts() async {
    try {
      Log.d('Loading products...');

      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds);

      if (response.error != null) {
        throw PaymentServiceException(
          'Failed to load products: ${response.error!.message}',
        );
      }

      _products = response.productDetails;

      if (_products.isEmpty) {
        Log.d('No products found. Check store configuration.');
      } else {
        Log.d('Loaded ${_products.length} products');
        for (var product in _products) {
          Log.d('  - ${product.id}: ${product.title} (${product.price})');
        }
      }
    } catch (e) {
      Log.d('Error loading products: $e');
      throw PaymentServiceException('Failed to load products: $e');
    }
  }

  /// Reads the entitlement the server holds (PRD F2).
  ///
  /// Was `_loadUserDataFromFirestore`, which read `users/{id}` — a document the
  /// client also **wrote**, which is the whole of F2's complaint: an
  /// entitlement a client can write is an entitlement a client can grant
  /// itself.
  ///
  /// `entitlements` is service-role write only (R9.5.1). This reads its own row
  /// through the read-own policy and can do nothing else with it, which is
  /// exactly the shape F2 asks for: **the client displays, the server decides.**
  ///
  /// Usage counters are no longer read here at all. The gateway owns them and
  /// reports them on every reply (`ChatUsage`), so a second, staler copy in
  /// this object would only be something to disagree with.
  Future<void> _loadUserData() async {
    if (_currentUserId == null) return;

    try {
      final row = await Supabase.instance.client
          .from('entitlements')
          .select('tier, state, expires_at')
          .eq('user_id', _currentUserId!)
          .maybeSingle();

      if (row == null) {
        _resetUserDataToDefaults();
        return;
      }

      final expiresAt = row['expires_at'] as String?;
      _subscriptionExpiryDate = expiresAt == null
          ? null
          : DateTime.tryParse(expiresAt)?.toLocal();

      // Mirrors the server's own reading in `consume_model_call`: a 'pro' row
      // that is cancelled, on hold, or past its expiry is a free user. Only
      // 'active' and 'grace' are live (§8.2).
      final state = row['state'] as String?;
      _isPremium =
          row['tier'] == 'pro' &&
          (state == 'active' || state == 'grace') &&
          (_subscriptionExpiryDate == null ||
              _subscriptionExpiryDate!.isAfter(DateTime.now()));

      _currentSubscriptionType = _isPremium ? row['tier'] as String? : null;
      _lastCacheUpdate = DateTime.now();
      Log.d('Entitlement loaded from the server: premium=$_isPremium');
    } catch (e) {
      // Fail closed. An unreadable entitlement is not a reason to assume Pro.
      Log.d('Error loading entitlement: $e');
      _resetUserDataToDefaults();
    }
  }

  // `_handleExpiredSubscription` stood here. It flipped the local premium
  // flag and wrote a cancellation to Firestore. Expiry is now decided in one
  // place, `consume_model_call`, which treats a 'pro' row that is cancelled,
  // on hold, or past its expiry as free — so there is nothing for a client to
  // decide and nowhere for it to write the decision.

  /// Reset user data to defaults
  void _resetUserDataToDefaults() {
    _isPremium = false;
    _currentSubscriptionType = null;
    _subscriptionExpiryDate = null;
    _dailyUsage = {'messages': 0, 'images': 0, 'voice': 0};
    _lastUsageReset = DateTime.now();
  }

  /// Check if cache is valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < cacheDuration;
  }

  /// Check if we should sync with Google Play
  bool _shouldSyncWithGooglePlay() {
    if (!_isPremium) return false;
    if (_subscriptionExpiryDate == null) return true;

    // Sync if subscription expires within 24 hours
    final hoursUntilExpiry = _subscriptionExpiryDate!
        .difference(DateTime.now())
        .inHours;
    return hoursUntilExpiry <= 24;
  }

  /// Sync subscription status with Google Play
  Future<void> _syncWithGooglePlay() async {
    try {
      Log.d('Syncing with Google Play...');

      // Only restore if user has existing subscription record
      if (_isPremium && _currentSubscriptionType != null) {
        await _inAppPurchase.restorePurchases();
        // Allow time for purchase stream to process
        await Future.delayed(const Duration(seconds: 2));

        // Reload data after restore
        await _loadUserData();
      }

      Log.d('Google Play sync completed');
    } catch (e) {
      Log.d('Error syncing with Google Play: $e');
    }
  }

  /// Purchase a subscription
  Future<void> purchaseSubscription(String productId) async {
    try {
      if (_currentUserId == null) {
        throw PaymentServiceException('User not authenticated');
      }

      if (_purchasePending) {
        throw PaymentServiceException('Purchase already in progress');
      }

      // Check for existing active subscription
      if (_isPremium &&
          _subscriptionExpiryDate?.isAfter(DateTime.now()) == true) {
        throw PaymentServiceException('Active subscription already exists');
      }

      final productDetails = _products.firstWhere(
        (product) => product.id == productId,
        orElse: () =>
            throw PaymentServiceException('Product not found: $productId'),
      );

      _purchasePending = true;

      final purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: _currentUserId,
      );

      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        _purchasePending = false;
        throw PaymentServiceException('Failed to initiate purchase');
      }

      Log.d('Purchase initiated for: $productId');
    } catch (e) {
      _purchasePending = false;
      Log.d('Purchase error: $e');
      onPurchaseResult?.call(false, _getErrorMessage(e));
    }
  }

  /// Handle purchase updates from stream
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      await _processPurchaseDetails(purchaseDetails);
    }
  }

  /// Process individual purchase details
  Future<void> _processPurchaseDetails(PurchaseDetails purchaseDetails) async {
    _purchasePending = false;

    try {
      switch (purchaseDetails.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(purchaseDetails);
          break;

        case PurchaseStatus.error:
          _handlePurchaseError(purchaseDetails);
          break;

        case PurchaseStatus.canceled:
          _handlePurchaseCancelled();
          break;

        case PurchaseStatus.pending:
          _handlePurchasePending();
          break;
      }
    } catch (e) {
      Log.d('Error processing purchase: $e');
      onPurchaseResult?.call(false, 'Purchase processing failed: $e');
    } finally {
      // Always complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase or restore
  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    try {
      if (_currentUserId == null) {
        throw PaymentServiceException('No authenticated user');
      }

      // Validate purchase
      if (!await _validatePurchase(purchaseDetails)) {
        throw PaymentServiceException('Purchase validation failed');
      }

      // NOTHING IS GRANTED HERE, AND THAT IS THE POINT.
      //
      // This used to write `isPremium: true` to Firestore and set the local
      // flag, on the strength of a purchase token the client had checked was
      // non-empty. F2 and R8.2 both forbid it: "An unverified purchase MUST NOT
      // grant access", and §14 requires proving that an unverified Play token
      // grants nothing.
      //
      // The verification path — client sends the token to the gateway, the
      // gateway checks it against the Google Play Developer API with a service
      // account, writes the `entitlements` row, and acknowledges the purchase —
      // is Milestone 6. Until it exists, a purchase deliberately does nothing,
      // which is a visible gap rather than a silent bypass. `entitlements` is
      // service-role write only, so this is also the only behaviour the schema
      // permits.
      //
      // TODO(m6): POST the token to verify-purchase and re-read the row.
      Log.w(
        'Purchase received but not verifiable yet (§8.2, Milestone 6). '
        'No entitlement granted.',
      );

      onPurchaseResult?.call(false, 'Purchases are not available yet.');
    } catch (e) {
      Log.d('Error handling successful purchase: $e');
      onPurchaseResult?.call(false, 'Failed to process purchase: $e');
    }
  }

  /// Validate purchase details
  Future<bool> _validatePurchase(PurchaseDetails purchaseDetails) async {
    try {
      // Validate product ID
      if (!productIds.contains(purchaseDetails.productID)) {
        Log.d('Invalid product ID: ${purchaseDetails.productID}');
        return false;
      }

      // Validate purchase token
      if (purchaseDetails.verificationData.localVerificationData.isEmpty) {
        Log.d('Missing verification data');
        return false;
      }

      // Validate purchase ID
      if (purchaseDetails.purchaseID?.isEmpty ?? true) {
        Log.d('Missing purchase ID');
        return false;
      }

      // Additional validation for restored purchases
      if (purchaseDetails.status == PurchaseStatus.restored) {
        return await _validateRestoredPurchase(purchaseDetails);
      }

      return true;
    } catch (e) {
      Log.d('Purchase validation error: $e');
      return false;
    }
  }

  /// Validate restored purchase
  /// Restore is not possible without server verification (R8.2, §14).
  ///
  /// This used to read the user's own Firestore document and grant a restore
  /// if it said `isPremium: true` — a client asking a client-writable record
  /// whether the client is premium. §14 requires proving "a patched client
  /// cannot gain Pro", and that check was the patch.
  ///
  /// A real restore re-verifies the token against the Play Developer API and
  /// re-reads `entitlements`. That is Milestone 6. Refusing until then is the
  /// correct answer rather than a stub: granting on an unverified token is the
  /// exact thing R8.2 forbids.
  Future<bool> _validateRestoredPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    Log.w('Restore requires server verification (§8.2, Milestone 6)');
    return false;
  }

  // `_saveSubscriptionToFirestore` stood here. It wrote isPremium, the
  // subscription type, the expiry, and the purchase token into a document the
  // client owned. Deleted with Firestore itself; `entitlements` is
  // service-role write only precisely so this shape cannot exist (R9.5.1).

  /// Handle purchase error
  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    final errorMessage = purchaseDetails.error != null
        ? _getReadableErrorMessage(purchaseDetails.error!)
        : 'Purchase failed with unknown error';

    Log.d('Purchase failed: $errorMessage');
    onPurchaseResult?.call(false, errorMessage);
  }

  /// Handle purchase cancellation
  void _handlePurchaseCancelled() {
    Log.d('Purchase cancelled by user');
    onPurchaseResult?.call(false, 'Purchase cancelled');
  }

  /// Handle pending purchase
  void _handlePurchasePending() {
    _purchasePending = true;
    Log.d('Purchase pending approval');
    onPurchaseResult?.call(
      false,
      'Purchase pending. Please wait for approval.',
    );
  }

  /// Get readable error message
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
      case 'network_error':
        return 'Network error. Please check your connection.';
      default:
        return error.message;
    }
  }

  /// Check and reset daily usage if needed
  Future<void> _checkAndResetDailyUsage() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastReset = DateTime(
      _lastUsageReset.year,
      _lastUsageReset.month,
      _lastUsageReset.day,
    );

    if (today.isAfter(lastReset)) {
      Log.d('Resetting daily usage');
      _dailyUsage = {'messages': 0, 'images': 0, 'voice': 0};
      _lastUsageReset = now;

      // Nothing to persist: usage_daily is the gateway's (R9.3.4).
    }
  }

  /// Usage validation methods
  bool canSendMessage() =>
      _isPremium || dailyMessageCount < freeDailyMessages;
  bool canUploadImage() => _isPremium || dailyImageCount < freeDailyImages;
  bool canSendVoice() => _isPremium || dailyVoiceCount < freeDailyVoice;
  bool canAccessAllPersonas() => _isPremium;

  /// Usage increment methods
  Future<void> incrementMessageCount() => _incrementUsage('messages');
  Future<void> incrementImageCount() => _incrementUsage('images');
  Future<void> incrementVoiceCount() => _incrementUsage('voice');

  /// Generic usage increment
  Future<void> _incrementUsage(String type) async {
    if (_isPremium) return;

    _dailyUsage[type] = (_dailyUsage[type] ?? 0) + 1;

    // Immediate save to Firestore
    try {
      // Nothing to persist: usage_daily is the gateway's (R9.3.4).
    } catch (e) {
      // Queue for later if offline
      _queueUsageUpdate();
    }
  }

  /// Save usage to Firestore
  // `_saveUsageToFirestore` stood here. Usage is the gateway's now, recorded
  // atomically with the response it accounts for (R9.3.4) in a table no client
  // can write. The counters left in this object are display-only and are
  // superseded by `ChatUsage`, which comes back on every reply.

  /// Queue usage update for later
  void _queueUsageUpdate() {
    _pendingUsageUpdates.add({
      'usage': Map<String, int>.from(_dailyUsage),
      'timestamp': DateTime.now(),
    });
  }

  /// Process pending usage updates
  Future<void> _processPendingUpdates() async {
    if (_pendingUsageUpdates.isEmpty) return;

    try {
      // Use latest update
      final latestUpdate = _pendingUsageUpdates.last;
      _dailyUsage = Map<String, int>.from(latestUpdate['usage']);

      // Nothing to persist: usage_daily is the gateway's (R9.3.4).
      _pendingUsageUpdates.clear();

      Log.d('Processed ${_pendingUsageUpdates.length} pending updates');
    } catch (e) {
      Log.d('Error processing pending updates: $e');
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _performPeriodicSync();
    });
  }

  /// Perform periodic sync
  Future<void> _performPeriodicSync() async {
    try {
      if (_currentUserId == null) return;

      // Refresh subscription status
      await _loadUserData();

      // Process pending updates
      await _processPendingUpdates();

      // Sync with Google Play if needed
      if (_shouldSyncWithGooglePlay()) {
        await _syncWithGooglePlay();
      }
    } catch (e) {
      Log.d('Periodic sync error: $e');
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    try {
      if (_currentUserId == null) {
        throw PaymentServiceException('Please log in to restore purchases');
      }

      await _inAppPurchase.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      await _loadUserData();

      Log.d('Purchases restored');
    } catch (e) {
      Log.d('Error restoring purchases: $e');
      throw PaymentServiceException('Failed to restore purchases: $e');
    }
  }

  /// Get subscription status text
  String getSubscriptionStatusText() {
    if (!_isPremium) return 'Free Plan';

    final type = _currentSubscriptionType == monthlySubscriptionId
        ? 'Monthly'
        : 'Yearly';

    if (_subscriptionExpiryDate != null) {
      final days = _subscriptionExpiryDate!.difference(DateTime.now()).inDays;
      return days > 0
          ? 'Premium $type ($days days left)'
          : 'Premium $type (Expired)';
    }

    return 'Premium $type';
  }

  /// Get usage text
  String getUsageText() {
    if (_isPremium) return 'Unlimited usage';

    return 'Messages: $dailyMessageCount/$freeDailyMessages, '
        'Images: $dailyImageCount/$freeDailyImages, '
        'Voice: $dailyVoiceCount/$freeDailyVoice';
  }

  /// Get error message
  String _getErrorMessage(dynamic error) {
    if (error is PaymentServiceException) {
      return error.message;
    }
    return error.toString();
  }

  /// Dispose resources
  void dispose() {
    Log.d('Disposing PaymentService...');

    _purchaseSubscription?.cancel();
    _authSubscription?.cancel();
    _syncTimer?.cancel();

    _purchaseSubscription = null;
    _authSubscription = null;
    _syncTimer = null;

    Log.d('PaymentService disposed');
  }
}

/// Custom exception for payment service errors
class PaymentServiceException implements Exception {
  final String message;
  PaymentServiceException(this.message);

  @override
  String toString() => 'PaymentServiceException: $message';
}
