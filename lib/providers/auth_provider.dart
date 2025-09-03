import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';
import '../services/payment_service.dart';

/// Enhanced AuthProvider with improved state management and error handling
class AuthProvider with ChangeNotifier {
  // Core services
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final PaymentService _paymentService = PaymentService();

  // State variables
  User? _firebaseUser;
  AppUser? _currentUser;

  // Status flags
  bool _isGoogleSignIn = false;
  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _isProcessingAuthChange = false;

  // Stream subscriptions for cleanup
  StreamSubscription<User?>? _authStateSubscription;
  Timer? _subscriptionCheckTimer;

  // Cache management
  DateTime? _lastUserDataRefresh;
  static const Duration USER_DATA_CACHE_DURATION = Duration(minutes: 3);

  // Public getters
  User? get user => _firebaseUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _firebaseUser != null && _currentUser != null;
  bool get isGoogleSignIn => _isGoogleSignIn;
  bool get isInitialized => _isInitialized;

  // User info getters
  String get displayName =>
      _currentUser?.username ?? _firebaseUser?.displayName ?? "User";
  String get email =>
      _currentUser?.email ?? _firebaseUser?.email ?? 'user@example.com';
  String? get userPhotoUrl => _currentUser?.photoUrl ?? _firebaseUser?.photoURL;

  // Subscription getters (delegated to current user data)
  bool get isPremium => _currentUser?.hasActiveSubscription ?? false;
  PaymentService get paymentService => _paymentService;

  String get subscriptionStatus {
    if (_currentUser?.hasActiveSubscription == true) {
      final type = _currentUser!.subscriptionType == 'premium_monthly'
          ? 'Monthly'
          : 'Yearly';
      final days = _currentUser!.daysUntilExpiry;
      return days > 0
          ? 'Premium $type ($days days left)'
          : 'Premium $type (Expired)';
    }
    return 'Free Plan';
  }

  String get usageText {
    if (_currentUser?.hasActiveSubscription == true) return 'Unlimited usage';

    if (_currentUser != null) {
      final messages = _currentUser!.dailyUsage['messages'] ?? 0;
      final images = _currentUser!.dailyUsage['images'] ?? 0;
      final voice = _currentUser!.dailyUsage['voice'] ?? 0;

      return 'Messages: $messages/${PaymentService.FREE_DAILY_MESSAGES}, '
          'Images: $images/${PaymentService.FREE_DAILY_IMAGES}, '
          'Voice: $voice/${PaymentService.FREE_DAILY_VOICE}';
    }

    return 'No usage data';
  }

  /// Constructor - Initialize the provider
  AuthProvider() {
    _initialize();
  }

  /// Initialize the auth provider
  Future<void> _initialize() async {
    try {
      print('🔄 Initializing AuthProvider...');

      // Initialize payment service first
      await _initializePaymentService();

      // Initialize Google Sign-In
      await _initializeGoogleSignIn();

      // Set up auth state listener
      _setupAuthStateListener();

      // Check current auth state
      _firebaseUser = _auth.currentUser;
      if (_firebaseUser != null) {
        await _handleUserSignIn(_firebaseUser!);
      }

      // Start periodic subscription checks
      _startPeriodicSubscriptionCheck();

      _isInitialized = true;
      print('✅ AuthProvider initialized successfully');
    } catch (e) {
      print('❌ AuthProvider initialization failed: $e');
      _isInitialized = true; // Set to true even on failure to prevent blocking
    }
  }

  /// Initialize payment service with callbacks
  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize();

      // Set up payment callbacks
      _paymentService.onPurchaseResult = _handlePurchaseResult;
      _paymentService.onSubscriptionStatusChanged =
          _handleSubscriptionStatusChange;

      print('✅ Payment service initialized with callbacks');
    } catch (e) {
      print('❌ Payment service initialization failed: $e');
    }
  }

  /// Initialize Google Sign-In
  Future<void> _initializeGoogleSignIn() async {
    try {
      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.initialize();
        print('✅ Google Sign-In initialized');
      } else {
        print('⚠️ Google Sign-In not supported on this platform');
      }
    } catch (e) {
      print('❌ Google Sign-In initialization failed: $e');
    }
  }

  /// Set up auth state change listener
  void _setupAuthStateListener() {
    _authStateSubscription?.cancel();

    _authStateSubscription = _auth.authStateChanges().listen(
      (User? user) => _handleAuthStateChange(user),
      onError: (error) => print('❌ Auth state change error: $error'),
    );
  }

  /// Handle authentication state changes
  Future<void> _handleAuthStateChange(User? user) async {
    if (_isProcessingAuthChange) {
      print('⚠️ Already processing auth change, skipping...');
      return;
    }

    _isProcessingAuthChange = true;

    try {
      _firebaseUser = user;

      if (user != null) {
        print('👤 User signed in: ${user.uid}');
        await _handleUserSignIn(user);
      } else {
        print('👋 User signed out');
        await _handleUserSignOut();
      }

      if (!_isRefreshing) {
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error handling auth state change: $e');
    } finally {
      _isProcessingAuthChange = false;
    }
  }

  /// Handle user sign in
  Future<void> _handleUserSignIn(User firebaseUser) async {
    try {
      print('🔄 Processing user sign-in: ${firebaseUser.uid}');

      // Clear previous payment service data
      await _paymentService.clearUserData();

      // Load or create user data
      await _loadOrCreateUserData(firebaseUser);

      // Initialize payment service for this user
      await _paymentService.initializeForUser(firebaseUser.uid);

      // Validate and sync subscription status
      await _validateAndSyncSubscriptionStatus();

      print('✅ User sign-in completed: ${firebaseUser.uid}');
    } catch (e) {
      print('❌ Error handling user sign-in: $e');
      throw AuthException('Failed to process user sign-in: $e');
    }
  }

  /// Load or create user data
  Future<void> _loadOrCreateUserData(User firebaseUser) async {
    try {
      // Try to load existing user data
      _currentUser = await _firestoreService.getUserWithCache(firebaseUser.uid);

      if (_currentUser == null) {
        // Create new user
        print('🆕 Creating new user profile');
        await _createNewUserProfile(firebaseUser);
      } else {
        // Update existing user if needed
        await _updateExistingUserProfile(firebaseUser);
      }

      _lastUserDataRefresh = DateTime.now();
      print('✅ User data loaded/created successfully');
    } catch (e) {
      print('❌ Error loading/creating user data: $e');
      rethrow;
    }
  }

  /// Create new user profile
  Future<void> _createNewUserProfile(User firebaseUser) async {
    final displayName =
        firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User';

    _currentUser = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email!,
      username: displayName,
      photoUrl: firebaseUser.photoURL ?? '',
      createdAt: DateTime.now(),
    );

    await _firestoreService.saveUserWithRetry(_currentUser!);
    print('✅ New user profile created');
  }

  /// Update existing user profile
  Future<void> _updateExistingUserProfile(User firebaseUser) async {
    bool needsUpdate = false;
    AppUser updatedUser = _currentUser!;

    // Update display name if changed
    final currentDisplayName =
        firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User';

    if (updatedUser.username != currentDisplayName) {
      updatedUser = updatedUser.copyWith(username: currentDisplayName);
      needsUpdate = true;
    }

    // Update photo URL if changed (for Google users)
    if (_isGoogleSignIn && firebaseUser.photoURL != updatedUser.photoUrl) {
      updatedUser = updatedUser.copyWith(photoUrl: firebaseUser.photoURL);
      needsUpdate = true;
    }

    // Reset daily usage if needed
    if (updatedUser.needsUsageReset()) {
      updatedUser = updatedUser.resetDailyUsage();
      needsUpdate = true;
      print('🔄 Daily usage reset for new day');
    }

    if (needsUpdate) {
      _currentUser = updatedUser;
      await _firestoreService.saveUserWithRetry(_currentUser!);
      print('✅ User profile updated');
    }
  }

  /// Handle user sign out
  Future<void> _handleUserSignOut() async {
    try {
      print('🔄 Processing user sign-out...');

      // Clear payment service data
      await _paymentService.clearUserData();

      // Clear user cache
      if (_currentUser != null) {
        _firestoreService.clearUserCache(_currentUser!.uid);
      }

      // Clear local state
      _currentUser = null;
      _isGoogleSignIn = false;
      _lastUserDataRefresh = null;

      print('✅ User sign-out completed');
    } catch (e) {
      print('❌ Error handling user sign-out: $e');
    }
  }

  /// Validate and sync subscription status
  Future<void> _validateAndSyncSubscriptionStatus() async {
    if (_currentUser == null) return;

    try {
      print('🔄 Validating subscription status...');

      bool needsUpdate = false;
      AppUser updatedUser = _currentUser!;

      // Check if subscription expired
      if (updatedUser.isSubscriptionExpired) {
        print('⚠️ Subscription expired, updating status...');
        await _firestoreService.cancelUserSubscription(_firebaseUser!.uid);
        updatedUser = updatedUser.copyWith(
          isPremium: false,
          subscriptionType: null,
          subscriptionExpiryDate: null,
        );
        needsUpdate = true;
      }

      // Save updates if needed
      if (needsUpdate) {
        _currentUser = updatedUser;
        await _firestoreService.saveUserWithRetry(_currentUser!);
        print('✅ Subscription status updated');
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error validating subscription: $e');
    }
  }

  /// Handle purchase result callback
  void _handlePurchaseResult(bool success, String message) {
    if (success) {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      _refreshUserDataFromFirestore();
    } else {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  /// Handle subscription status change callback
  void _handleSubscriptionStatusChange(bool isSubscribed) {
    print('💳 Subscription status changed: $isSubscribed');
    _refreshUserDataFromFirestore();
  }

  /// Refresh user data from Firestore
  Future<void> _refreshUserDataFromFirestore() async {
    if (_firebaseUser == null || _isRefreshing) return;

    _isRefreshing = true;

    try {
      print('🔄 Refreshing user data from Firestore...');

      final freshUserData = await _firestoreService.getUser(_firebaseUser!.uid);
      if (freshUserData != null) {
        _currentUser = freshUserData;
        _lastUserDataRefresh = DateTime.now();
        print('✅ User data refreshed');
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Start periodic subscription status checks
  void _startPeriodicSubscriptionCheck() {
    _subscriptionCheckTimer?.cancel();

    _subscriptionCheckTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _validateAndSyncSubscriptionStatus(),
    );
  }

  /// Check if user data cache is valid
  bool _isUserDataCacheValid() {
    if (_lastUserDataRefresh == null) return false;
    return DateTime.now().difference(_lastUserDataRefresh!) <
        USER_DATA_CACHE_DURATION;
  }

  // AUTHENTICATION METHODS

  /// Sign up with email and password
  Future<bool> signUp(String email, String password, String username) async {
    try {
      _isGoogleSignIn = false;

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? true;

      // User data will be handled by auth state change listener

      return isNewUser;
    } catch (e) {
      print('❌ Sign up error: $e');
      throw AuthException(_getAuthErrorMessage(e));
    }
  }

  /// Login with email and password
  Future<void> login(String email, String password) async {
    try {
      _isGoogleSignIn = false;

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // User data will be handled by auth state change listener
    } catch (e) {
      print('❌ Login error: $e');
      throw AuthException(_getAuthErrorMessage(e));
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      if (!_googleSignIn.supportsAuthenticate()) {
        throw AuthException('Google Sign-In not supported on this platform');
      }

      _isGoogleSignIn = true;

      // Authenticate with Google
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      // Get authorization
      final authClient = _googleSignIn.authorizationClient;
      final authorization = await authClient.authorizationForScopes(['email']);

      if (authorization == null) {
        throw AuthException('Failed to get Google authorization');
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      await _auth.signInWithCredential(credential);

      // User data will be handled by auth state change listener

      print('✅ Google sign-in completed');
    } on GoogleSignInException catch (e) {
      _isGoogleSignIn = false;
      print('❌ Google Sign-In error: $e');
      throw AuthException(_getGoogleSignInErrorMessage(e));
    } catch (e) {
      _isGoogleSignIn = false;
      print('❌ Google Sign-In error: $e');
      throw AuthException('Google Sign-In failed: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      print('🔄 Starting logout process...');

      // Sign out from Google if applicable
      if (_isGoogleSignIn) {
        try {
          await _googleSignIn.signOut();
          await _googleSignIn.disconnect();
        } catch (e) {
          print('⚠️ Google sign-out warning: $e');
        }
      }

      // Sign out from Firebase (this will trigger auth state change)
      await _auth.signOut();

      print('✅ Logout completed');
    } catch (e) {
      print('❌ Logout error: $e');
      throw AuthException('Logout failed: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      throw AuthException('Failed to send password reset email');
    }
  }

  // USER PROFILE METHODS

  /// Upload user photo
  Future<void> uploadUserPhoto(File imageFile) async {
    try {
      if (_firebaseUser == null || _currentUser == null) {
        throw AuthException('User not authenticated');
      }

      final downloadUrl = await _cloudinaryService.uploadImage(imageFile);
      if (downloadUrl == null) {
        throw AuthException('Image upload failed');
      }

      _currentUser = _currentUser!.copyWith(photoUrl: downloadUrl);
      await _firestoreService.saveUserWithRetry(_currentUser!);

      Fluttertoast.showToast(
        msg: '✅ Photo uploaded successfully!',
        backgroundColor: Colors.green,
      );

      notifyListeners();
    } catch (e) {
      print('❌ Photo upload error: $e');
      Fluttertoast.showToast(
        msg: '❌ Failed to upload photo',
        backgroundColor: Colors.red,
      );
      throw AuthException('Photo upload failed: $e');
    }
  }

  /// Set user avatar
  Future<void> setUserAvatar(String avatarUrl) async {
    try {
      if (_firebaseUser == null || _currentUser == null) {
        throw AuthException('User not authenticated');
      }

      _currentUser = _currentUser!.copyWith(photoUrl: avatarUrl);
      await _firestoreService.saveUserWithRetry(_currentUser!);

      notifyListeners();
    } catch (e) {
      print('❌ Avatar setting error: $e');
      throw AuthException('Failed to set avatar: $e');
    }
  }

  // USAGE METHODS

  /// Check if user can send message
  Future<bool> canSendMessage() async {
    await _ensureUserDataFresh();

    if (_currentUser?.hasActiveSubscription == true) return true;

    if (_currentUser != null) {
      final currentMessages = _currentUser!.dailyUsage['messages'] ?? 0;
      return currentMessages < PaymentService.FREE_DAILY_MESSAGES;
    }

    return false;
  }

  /// Check if user can upload image
  Future<bool> canUploadImage() async {
    await _ensureUserDataFresh();

    if (_currentUser?.hasActiveSubscription == true) return true;

    if (_currentUser != null) {
      final currentImages = _currentUser!.dailyUsage['images'] ?? 0;
      return currentImages < PaymentService.FREE_DAILY_IMAGES;
    }

    return false;
  }

  /// Check if user can send voice
  Future<bool> canSendVoice() async {
    await _ensureUserDataFresh();

    if (_currentUser?.hasActiveSubscription == true) return true;

    if (_currentUser != null) {
      final currentVoice = _currentUser!.dailyUsage['voice'] ?? 0;
      return currentVoice < PaymentService.FREE_DAILY_VOICE;
    }

    return false;
  }

  /// Check if user can generate image
  Future<bool> canGenerateImage() async {
    await _ensureUserDataFresh();

    if (_currentUser?.hasActiveSubscription == true) return true;

    if (_currentUser != null) {
      final currentImages = _currentUser!.dailyUsage['images'] ?? 0;
      return currentImages < PaymentService.FREE_DAILY_IMAGES;
    }

    return false;
  }

  /// Check if user can access all personas
  bool canAccessAllPersonas() {
    return _currentUser?.hasActiveSubscription == true;
  }

  /// Increment message usage
  Future<void> incrementMessageUsage() async {
    await _incrementUsage('messages');
  }

  /// Increment image usage
  Future<void> incrementImageUsage() async {
    await _incrementUsage('images');
  }

  /// Increment voice usage
  Future<void> incrementVoiceUsage() async {
    await _incrementUsage('voice');
  }

  /// Increment image generation usage
  Future<void> incrementImageGenerationUsage() async {
    await _incrementUsage('images');
  }

  /// Generic usage increment
  Future<void> _incrementUsage(String type) async {
    if (_currentUser?.hasActiveSubscription == true) return;
    if (_currentUser == null) return;

    try {
      // Update local user data
      _currentUser = _currentUser!.incrementUsage(type);

      // Save to Firestore
      await _firestoreService.saveUserWithRetry(_currentUser!);

      // Update payment service
      switch (type) {
        case 'messages':
          await _paymentService.incrementMessageCount();
          break;
        case 'images':
          await _paymentService.incrementImageCount();
          break;
        case 'voice':
          await _paymentService.incrementVoiceCount();
          break;
      }

      notifyListeners();
      print('✅ $type usage incremented: ${_currentUser!.dailyUsage[type]}');
    } catch (e) {
      print('❌ Error incrementing $type usage: $e');
    }
  }

  // HELPER METHODS

  /// Ensure user data is fresh
  Future<void> _ensureUserDataFresh() async {
    if (!_isUserDataCacheValid()) {
      await _refreshUserDataFromFirestore();
    }
  }

  /// Check if user has completed profile setup
  bool get hasCompletedProfile {
    if (_isGoogleSignIn) return true;
    return _currentUser?.photoUrl?.isNotEmpty == true;
  }

  /// Check if user needs photo upload
  bool get needsPhotoUpload {
    return !_isGoogleSignIn && !hasCompletedProfile;
  }

  /// Check if user is new
  Future<bool> checkIfNewUser() async {
    try {
      if (_firebaseUser == null) return false;

      if (_isGoogleSignIn) {
        return _currentUser == null;
      } else {
        return _currentUser?.photoUrl?.isEmpty != false;
      }
    } catch (e) {
      print('❌ Error checking if new user: $e');
      return false;
    }
  }

  // ERROR MESSAGE HELPERS

  /// Get readable auth error message
  String _getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error.code);
    }
    return error.toString();
  }

  /// Get Firebase auth error message
  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Get Google Sign-In error message
  String _getGoogleSignInErrorMessage(GoogleSignInException exception) {
    switch (exception.code.name) {
      case 'canceled':
        return 'Sign-in was cancelled.';
      case 'interrupted':
        return 'Sign-in was interrupted. Please try again.';
      case 'clientConfigurationError':
      case 'providerConfigurationError':
        return 'Google Sign-In configuration error. Please contact support.';
      case 'uiUnavailable':
        return 'Google Sign-In is currently unavailable.';
      case 'userMismatch':
        return 'Account mismatch detected. Please sign out and try again.';
      default:
        return 'Google Sign-In failed. Please try again.';
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    print('🧹 Disposing AuthProvider...');

    _authStateSubscription?.cancel();
    _subscriptionCheckTimer?.cancel();
    _paymentService.dispose();

    super.dispose();

    print('✅ AuthProvider disposed');
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
