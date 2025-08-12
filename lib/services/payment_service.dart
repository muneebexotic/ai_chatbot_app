import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

/// Enhanced PaymentService with improved error handling, performance, and reliability
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Core services
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Stream subscriptions for proper cleanup
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StreamSubscription<User?>? _authSubscription;
  
  // Product configurations
  static const String monthlySubscriptionId = 'premium_monthly';
  static const String yearlySubscriptionId = 'premium_yearly';
  static const Set<String> productIds = {monthlySubscriptionId, yearlySubscriptionId};

  // Free tier limits
  static const int FREE_DAILY_MESSAGES = 20;
  static const int FREE_DAILY_IMAGES = 3;
  static const int FREE_DAILY_VOICE = 5;
  static const int FREE_PERSONAS_COUNT = 3;

  // State management
  List<ProductDetails> _products = [];
  bool _purchasePending = false;
  bool _isInitialized = false;
  String? _currentUserId;
  
  // Subscription data (cached from Firestore)
  bool _isPremium = false;
  DateTime? _subscriptionExpiryDate;
  String? _currentSubscriptionType;
  
  // Usage tracking (cached from Firestore)
  Map<String, int> _dailyUsage = {'messages': 0, 'images': 0, 'voice': 0};
  DateTime _lastUsageReset = DateTime.now();
  
  // Cache management
  DateTime? _lastCacheUpdate;
  static const Duration CACHE_DURATION = Duration(minutes: 5);
  
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
      : (FREE_DAILY_MESSAGES - dailyMessageCount).clamp(0, FREE_DAILY_MESSAGES);
  int get remainingImages => _isPremium 
      ? -1 
      : (FREE_DAILY_IMAGES - dailyImageCount).clamp(0, FREE_DAILY_IMAGES);
  int get remainingVoice => _isPremium 
      ? -1 
      : (FREE_DAILY_VOICE - dailyVoiceCount).clamp(0, FREE_DAILY_VOICE);

  // Callback functions
  Function(bool success, String message)? onPurchaseResult;
  Function(bool isSubscribed)? onSubscriptionStatusChanged;
  Function()? onUsageLimitReached;

  /// Initialize the payment service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔄 Initializing PaymentService...');
      
      // Check in-app purchase availability
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw PaymentServiceException('In-app purchases not available on this device');
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
      print('✅ PaymentService initialized successfully');
      
    } catch (e) {
      print('❌ PaymentService initialization failed: $e');
      rethrow;
    }
  }

  /// Set up purchase stream listener
  Future<void> _setupPurchaseStream() async {
    await _purchaseSubscription?.cancel();
    
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        print('❌ Purchase stream error: $error');
        _purchasePending = false;
      },
      onDone: () => print('🔄 Purchase stream closed'),
    );
  }

  /// Set up auth state listener for user changes
  void _setupAuthStateListener() {
    _authSubscription?.cancel();
    
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) async {
        if (user?.uid != _currentUserId) {
          print('👤 User changed: ${user?.uid}');
          await _handleUserChange(user);
        }
      },
      onError: (error) => print('❌ Auth state listener error: $error'),
    );
  }

  /// Handle user authentication changes
  Future<void> _handleUserChange(User? user) async {
    try {
      if (user == null) {
        await clearUserData();
      } else if (user.uid != _currentUserId) {
        await initializeForUser(user.uid);
      }
    } catch (e) {
      print('❌ Error handling user change: $e');
    }
  }

  /// Initialize for a specific user
  Future<void> initializeForUser(String userId) async {
    try {
      print('🔄 Initializing for user: $userId');
      
      if (_currentUserId == userId && _isCacheValid()) {
        print('✅ Using cached data for user: $userId');
        return;
      }
      
      _currentUserId = userId;
      await _loadUserDataFromFirestore();
      await _checkAndResetDailyUsage();
      await _processPendingUpdates();
      
      // Sync with Google Play if needed
      if (_isPremium && _shouldSyncWithGooglePlay()) {
        await _syncWithGooglePlay();
      }
      
      print('✅ User initialization completed for: $userId');
      
    } catch (e) {
      print('❌ Error initializing for user: $e');
      throw PaymentServiceException('Failed to initialize user data: $e');
    }
  }

  /// Clear all user data
  Future<void> clearUserData() async {
    try {
      print('🧹 Clearing user data...');
      
      _currentUserId = null;
      _isPremium = false;
      _subscriptionExpiryDate = null;
      _currentSubscriptionType = null;
      _dailyUsage = {'messages': 0, 'images': 0, 'voice': 0};
      _lastUsageReset = DateTime.now();
      _lastCacheUpdate = null;
      _pendingUsageUpdates.clear();
      
      print('✅ User data cleared');
    } catch (e) {
      print('❌ Error clearing user data: $e');
    }
  }

  /// Load products from store
  Future<void> _loadProducts() async {
    try {
      print('🛍️ Loading products...');
      
      final ProductDetailsResponse response = 
          await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.error != null) {
        throw PaymentServiceException('Failed to load products: ${response.error!.message}');
      }
      
      _products = response.productDetails;
      
      if (_products.isEmpty) {
        print('⚠️ No products found. Check store configuration.');
      } else {
        print('✅ Loaded ${_products.length} products');
        for (var product in _products) {
          print('  - ${product.id}: ${product.title} (${product.price})');
        }
      }
      
    } catch (e) {
      print('❌ Error loading products: $e');
      throw PaymentServiceException('Failed to load products: $e');
    }
  }

  /// Load user data from Firestore
  Future<void> _loadUserDataFromFirestore() async {
    if (_currentUserId == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .get();
      
      if (!userDoc.exists || userDoc.data() == null) {
        _resetUserDataToDefaults();
        return;
      }
      
      final data = userDoc.data()!;
      
      // Load subscription data
      _isPremium = data['isPremium'] ?? false;
      _currentSubscriptionType = data['subscriptionType'];
      
      if (data['subscriptionExpiryDate'] != null) {
        _subscriptionExpiryDate = (data['subscriptionExpiryDate'] as Timestamp).toDate();
        
        // Check if subscription has expired
        if (_subscriptionExpiryDate!.isBefore(DateTime.now())) {
          print('⚠️ Subscription expired, updating status');
          await _handleExpiredSubscription();
        }
      }
      
      // Load usage data
      final usageData = data['dailyUsage'] as Map<String, dynamic>?;
      if (usageData != null) {
        _dailyUsage = Map<String, int>.from(usageData);
      }
      
      if (data['lastUsageReset'] != null) {
        _lastUsageReset = (data['lastUsageReset'] as Timestamp).toDate();
      }
      
      _lastCacheUpdate = DateTime.now();
      print('✅ User data loaded from Firestore');
      
    } catch (e) {
      print('❌ Error loading user data: $e');
      _resetUserDataToDefaults();
    }
  }

  /// Handle expired subscription
  Future<void> _handleExpiredSubscription() async {
    try {
      _isPremium = false;
      _currentSubscriptionType = null;
      _subscriptionExpiryDate = null;
      
      if (_currentUserId != null) {
        await _firestoreService.cancelUserSubscription(_currentUserId!);
        onSubscriptionStatusChanged?.call(false);
      }
      
    } catch (e) {
      print('❌ Error handling expired subscription: $e');
    }
  }

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
    return DateTime.now().difference(_lastCacheUpdate!) < CACHE_DURATION;
  }

  /// Check if we should sync with Google Play
  bool _shouldSyncWithGooglePlay() {
    if (!_isPremium) return false;
    if (_subscriptionExpiryDate == null) return true;
    
    // Sync if subscription expires within 24 hours
    final hoursUntilExpiry = _subscriptionExpiryDate!.difference(DateTime.now()).inHours;
    return hoursUntilExpiry <= 24;
  }

  /// Sync subscription status with Google Play
  Future<void> _syncWithGooglePlay() async {
    try {
      print('🔄 Syncing with Google Play...');
      
      // Only restore if user has existing subscription record
      if (_isPremium && _currentSubscriptionType != null) {
        await _inAppPurchase.restorePurchases();
        // Allow time for purchase stream to process
        await Future.delayed(const Duration(seconds: 2));
        
        // Reload data after restore
        await _loadUserDataFromFirestore();
      }
      
      print('✅ Google Play sync completed');
      
    } catch (e) {
      print('❌ Error syncing with Google Play: $e');
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
      if (_isPremium && _subscriptionExpiryDate?.isAfter(DateTime.now()) == true) {
        throw PaymentServiceException('Active subscription already exists');
      }
      
      final productDetails = _products.firstWhere(
        (product) => product.id == productId,
        orElse: () => throw PaymentServiceException('Product not found: $productId'),
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
      
      print('🛒 Purchase initiated for: $productId');
      
    } catch (e) {
      _purchasePending = false;
      print('❌ Purchase error: $e');
      onPurchaseResult?.call(false, _getErrorMessage(e));
    }
  }

  /// Handle purchase updates from stream
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
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
      print('❌ Error processing purchase: $e');
      onPurchaseResult?.call(false, 'Purchase processing failed: $e');
    } finally {
      // Always complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase or restore
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    try {
      if (_currentUserId == null) {
        throw PaymentServiceException('No authenticated user');
      }
      
      // Validate purchase
      if (!await _validatePurchase(purchaseDetails)) {
        throw PaymentServiceException('Purchase validation failed');
      }
      
      // Calculate subscription dates
      final subscriptionData = _calculateSubscriptionDates(purchaseDetails);
      
      // Save to Firestore
      await _saveSubscriptionToFirestore(purchaseDetails, subscriptionData);
      
      // Update local cache
      _isPremium = true;
      _currentSubscriptionType = purchaseDetails.productID;
      _subscriptionExpiryDate = subscriptionData['expiryDate'];
      _lastCacheUpdate = DateTime.now();
      
      final isRestored = purchaseDetails.status == PurchaseStatus.restored;
      final message = isRestored 
          ? 'Subscription restored successfully!' 
          : 'Subscription activated successfully!';
          
      onPurchaseResult?.call(true, message);
      onSubscriptionStatusChanged?.call(true);
      
      print('✅ Purchase processed successfully');
      
    } catch (e) {
      print('❌ Error handling successful purchase: $e');
      onPurchaseResult?.call(false, 'Failed to process purchase: $e');
    }
  }

  /// Validate purchase details
  Future<bool> _validatePurchase(PurchaseDetails purchaseDetails) async {
    try {
      // Validate product ID
      if (!productIds.contains(purchaseDetails.productID)) {
        print('❌ Invalid product ID: ${purchaseDetails.productID}');
        return false;
      }
      
      // Validate purchase token
      if (purchaseDetails.verificationData.localVerificationData.isEmpty) {
        print('❌ Missing verification data');
        return false;
      }
      
      // Validate purchase ID
      if (purchaseDetails.purchaseID?.isEmpty ?? true) {
        print('❌ Missing purchase ID');
        return false;
      }
      
      // Additional validation for restored purchases
      if (purchaseDetails.status == PurchaseStatus.restored) {
        return await _validateRestoredPurchase(purchaseDetails);
      }
      
      return true;
      
    } catch (e) {
      print('❌ Purchase validation error: $e');
      return false;
    }
  }

  /// Validate restored purchase
  Future<bool> _validateRestoredPurchase(PurchaseDetails purchaseDetails) async {
    try {
      // Only allow restore if user previously had a subscription
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .get();
      
      if (!userDoc.exists) {
        print('❌ No user record found for restore');
        return false;
      }
      
      final userData = userDoc.data()!;
      final hadPreviousSubscription = userData['isPremium'] == true || 
                                     userData['subscriptionType'] != null;
      
      if (!hadPreviousSubscription) {
        print('❌ User never had a subscription');
        return false;
      }
      
      return true;
      
    } catch (e) {
      print('❌ Restored purchase validation error: $e');
      return false;
    }
  }

  /// Calculate subscription dates based on product type
  Map<String, DateTime> _calculateSubscriptionDates(PurchaseDetails purchaseDetails) {
    final now = DateTime.now();
    final duration = purchaseDetails.productID == monthlySubscriptionId 
        ? const Duration(days: 30)
        : const Duration(days: 365);
    
    return {
      'startDate': now,
      'expiryDate': now.add(duration),
    };
  }

  /// Save subscription to Firestore
  Future<void> _saveSubscriptionToFirestore(
    PurchaseDetails purchaseDetails, 
    Map<String, DateTime> dates,
  ) async {
    if (_currentUserId == null) return;
    
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId!);
        
        final subscriptionData = {
          'isPremium': true,
          'subscriptionType': purchaseDetails.productID,
          'subscriptionStartDate': Timestamp.fromDate(dates['startDate']!),
          'subscriptionExpiryDate': Timestamp.fromDate(dates['expiryDate']!),
          'purchaseToken': purchaseDetails.verificationData.localVerificationData,
          'purchaseId': purchaseDetails.purchaseID,
          'lastPurchaseDate': Timestamp.fromDate(DateTime.now()),
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'verified': true,
        };
        
        transaction.update(userRef, subscriptionData);
        
        // Store purchase history
        final historyRef = userRef.collection('subscription_history').doc();
        transaction.set(historyRef, {
          ...subscriptionData,
          'purchaseTimestamp': Timestamp.fromDate(DateTime.now()),
        });
      });
      
      print('✅ Subscription saved to Firestore');
      
    } catch (e) {
      print('❌ Error saving subscription: $e');
      throw PaymentServiceException('Failed to save subscription: $e');
    }
  }

  /// Handle purchase error
  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    final errorMessage = purchaseDetails.error != null
        ? _getReadableErrorMessage(purchaseDetails.error!)
        : 'Purchase failed with unknown error';
    
    print('❌ Purchase failed: $errorMessage');
    onPurchaseResult?.call(false, errorMessage);
  }

  /// Handle purchase cancellation
  void _handlePurchaseCancelled() {
    print('⚠️ Purchase cancelled by user');
    onPurchaseResult?.call(false, 'Purchase cancelled');
  }

  /// Handle pending purchase
  void _handlePurchasePending() {
    _purchasePending = true;
    print('⏳ Purchase pending approval');
    onPurchaseResult?.call(false, 'Purchase pending. Please wait for approval.');
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
        return error.message ?? 'An unexpected error occurred';
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
      print('🔄 Resetting daily usage');
      _dailyUsage = {'messages': 0, 'images': 0, 'voice': 0};
      _lastUsageReset = now;
      
      await _saveUsageToFirestore();
    }
  }

  /// Usage validation methods
  bool canSendMessage() => _isPremium || dailyMessageCount < FREE_DAILY_MESSAGES;
  bool canUploadImage() => _isPremium || dailyImageCount < FREE_DAILY_IMAGES;
  bool canSendVoice() => _isPremium || dailyVoiceCount < FREE_DAILY_VOICE;
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
      await _saveUsageToFirestore();
    } catch (e) {
      // Queue for later if offline
      _queueUsageUpdate();
    }
  }

  /// Save usage to Firestore
  Future<void> _saveUsageToFirestore() async {
    if (_currentUserId == null) {
      _queueUsageUpdate();
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .update({
            'dailyUsage': _dailyUsage,
            'lastUsageReset': Timestamp.fromDate(_lastUsageReset),
          });

      print('✅ Usage saved to Firestore');
      
    } catch (e) {
      print('❌ Error saving usage: $e');
      _queueUsageUpdate();
    }
  }

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
      
      await _saveUsageToFirestore();
      _pendingUsageUpdates.clear();
      
      print('✅ Processed ${_pendingUsageUpdates.length} pending updates');
      
    } catch (e) {
      print('❌ Error processing pending updates: $e');
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
      await _loadUserDataFromFirestore();
      
      // Process pending updates
      await _processPendingUpdates();
      
      // Sync with Google Play if needed
      if (_shouldSyncWithGooglePlay()) {
        await _syncWithGooglePlay();
      }
      
    } catch (e) {
      print('❌ Periodic sync error: $e');
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
      await _loadUserDataFromFirestore();
      
      print('✅ Purchases restored');
      
    } catch (e) {
      print('❌ Error restoring purchases: $e');
      throw PaymentServiceException('Failed to restore purchases: $e');
    }
  }

  /// Get subscription status text
  String getSubscriptionStatusText() {
    if (!_isPremium) return 'Free Plan';

    final type = _currentSubscriptionType == monthlySubscriptionId
        ? 'Monthly' : 'Yearly';
        
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

    return 'Messages: ${dailyMessageCount}/$FREE_DAILY_MESSAGES, '
           'Images: ${dailyImageCount}/$FREE_DAILY_IMAGES, '
           'Voice: ${dailyVoiceCount}/$FREE_DAILY_VOICE';
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
    print('🧹 Disposing PaymentService...');
    
    _purchaseSubscription?.cancel();
    _authSubscription?.cancel();
    _syncTimer?.cancel();
    
    _purchaseSubscription = null;
    _authSubscription = null;
    _syncTimer = null;
    
    print('✅ PaymentService disposed');
  }
}

/// Custom exception for payment service errors
class PaymentServiceException implements Exception {
  final String message;
  PaymentServiceException(this.message);
  
  @override
  String toString() => 'PaymentServiceException: $message';
}