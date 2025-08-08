import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';
import '../services/payment_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final PaymentService _paymentService = PaymentService();

  User? user;
  AppUser? currentUser;
  GoogleSignInAccount? _googleSignInAccount;
  bool _isGoogleSignIn = false;
  bool _isGoogleSignInInitialized = false;
  bool _isPaymentServiceInitialized = false;
  bool _isRefreshing = false;
  bool? _lastKnownPremiumStatus;

  String get displayName => currentUser?.username ?? "User";
  String? _userPhotoUrl;
  String? get userPhotoUrl => _userPhotoUrl ?? currentUser?.photoUrl;
  String get email => currentUser?.email ?? 'user@example.com';

  // CRITICAL FIX: Payment service getters - Always use Firestore data as single source of truth
  PaymentService get paymentService => _paymentService;
  bool get isPremium =>
      currentUser?.hasActiveSubscription ?? false; // Only from Firestore
  String get subscriptionStatus => _getSubscriptionStatus();
  String get usageText => _getUsageText();

  AuthProvider() {
    user = _auth.currentUser;
    _initializeServices();
    _auth.authStateChanges().listen((u) async {
      user = u;
      if (user != null) {
        print('✅ Firebase user detected: ${user!.uid}');
        await _handleUserSignIn(user!);
      } else {
        print('👋 User signed out or null');
        await _handleUserSignOut();
      }
      notifyListeners();
    });
  }

  // CRITICAL FIX: Enhanced user sign-in with proper isolation
  Future<void> _handleUserSignIn(User firebaseUser) async {
    try {
      print('🔄 Handling user sign-in: ${firebaseUser.uid}');

      // CRITICAL: Clear payment service before loading new user
      await _paymentService.clearUserData();

      // Load user data from Firestore
      currentUser = await _firestoreService.getUser(firebaseUser.uid);
      print('✅ Firestore user loaded: ${currentUser?.uid}');
      _userPhotoUrl = currentUser?.photoUrl;

      // CRITICAL: Initialize payment service for this specific user AFTER loading user data
      await _paymentService.initializeForUser();

      // Sync and validate subscription status
      await _validateAndSyncUserSubscription();

      print(
        '✅ User sign-in completed for: ${firebaseUser.uid}, Premium: ${currentUser?.hasActiveSubscription}',
      );
    } catch (e) {
      print('❌ Error handling user sign-in: $e');
    }
  }

  // CRITICAL FIX: Complete user sign-out with proper cleanup
  Future<void> _handleUserSignOut() async {
    try {
      print('🔄 Handling user sign-out...');

      // CRITICAL: Clear payment service data FIRST
      await _paymentService.clearUserData();

      // Clear local user data
      currentUser = null;
      _userPhotoUrl = null;
      _isGoogleSignIn = false;
      _googleSignInAccount = null;

      print('✅ User sign-out cleanup completed');
    } catch (e) {
      print('❌ Error handling user sign-out: $e');
    }
  }

  // CRITICAL FIX: Validate and sync subscription status with comprehensive checks
  Future<void> _validateAndSyncUserSubscription() async {
    if (currentUser == null) return;

    try {
      print('🔄 Validating and syncing subscription status...');

      bool needsUpdate = false;
      AppUser updatedUser = currentUser!;

      // Check if subscription has expired in Firestore
      if (updatedUser.isSubscriptionExpired) {
        print('⚠️ User subscription expired in Firestore, updating...');
        await _firestoreService.cancelUserSubscription(user!.uid);
        updatedUser = updatedUser.copyWith(
          isPremium: false,
          subscriptionType: null,
          subscriptionExpiryDate: null,
        );
        needsUpdate = true;
      }

      // Reset daily usage if needed
      if (updatedUser.needsUsageReset()) {
        print('🔄 Resetting daily usage for new day');
        updatedUser = updatedUser.resetDailyUsage();
        needsUpdate = true;
      }

      // Save updated user data if changes were made
      if (needsUpdate) {
        await _firestoreService.saveUser(updatedUser);
        currentUser = updatedUser;
        print('✅ User data updated and synced');
      }

      // Validate against payment service
      final paymentServicePremium = _paymentService.isPremium;
      final firestorePremium = currentUser!.hasActiveSubscription;

      if (paymentServicePremium != firestorePremium) {
        print('⚠️ Subscription status mismatch detected!');
        print('📱 Payment Service: $paymentServicePremium');
        print('🔥 Firestore: $firestorePremium');

        // Firestore is the single source of truth - update payment service
        print('🔄 Updating payment service to match Firestore...');
        await _paymentService.initializeForUser(); // Re-sync with Firestore
      }

      print('✅ Subscription validation completed');
      notifyListeners();
    } catch (e) {
      print('❌ Error validating subscription: $e');
    }
  }

  // Initialize both Google Sign-In and Payment Service
  Future<void> _initializeServices() async {
    await _initializeGoogleSignIn();
    await _initializePaymentService();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
      _isGoogleSignInInitialized = true;
      print('✅ Google Sign-In initialized');
    } catch (e) {
      print('❌ Failed to initialize Google Sign-In: $e');
      _isGoogleSignInInitialized = false;
    }
  }

  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize();

      // Set up payment callbacks
      _paymentService.onPurchaseResult = (success, message) {
        _handlePurchaseResult(success, message);
      };

      _paymentService.onSubscriptionStatusChanged = (isSubscribed) {
        _handleSubscriptionStatusChange(isSubscribed);
      };

      _isPaymentServiceInitialized = true;
      print('✅ Payment Service initialized');
    } catch (e) {
      print('❌ Failed to initialize Payment Service: $e');
      _isPaymentServiceInitialized = false;
    }
  }

  void _handlePurchaseResult(bool success, String message) {
    if (success) {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      // CRITICAL: Refresh user data from Firestore after successful purchase
      _refreshUserDataFromFirestore();
    } else {
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _handleSubscriptionStatusChange(bool isSubscribed) {
    print('💳 Subscription status changed: $isSubscribed');
    // Only refresh if status actually changed
    if (_lastKnownPremiumStatus != isSubscribed) {
      _refreshUserDataFromFirestore();
    }
  }

  // CRITICAL FIX: Always refresh from Firestore as single source of truth
  Future<void> _refreshUserDataFromFirestore() async {
    if (user == null || _isRefreshing)
      return; // Prevent multiple simultaneous refreshes

    _isRefreshing = true; // Add this flag to your class

    try {
      print('🔄 Refreshing user data from Firestore...');

      // Reload user data from Firestore (single source of truth)
      final freshUserData = await _firestoreService.getUser(user!.uid);

      if (freshUserData != null) {
        currentUser = freshUserData;

        // Only re-initialize payment service if subscription status actually changed
        final oldPremiumStatus = _lastKnownPremiumStatus;
        final newPremiumStatus = currentUser!.hasActiveSubscription;

        if (oldPremiumStatus != newPremiumStatus) {
          _lastKnownPremiumStatus = newPremiumStatus;
          await _paymentService.initializeForUser();
          print('✅ Payment service re-initialized due to subscription change');
        }
      }

      print('✅ User data refreshed from Firestore');
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  // Ensure services are initialized before use
  Future<void> _ensureServicesInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
    }
    if (!_isPaymentServiceInitialized) {
      await _initializePaymentService();
    }
  }

  // CRITICAL FIX: Usage validation methods - Firestore as primary source
  Future<bool> canSendMessage() async {
    // CRITICAL: Always check Firestore user data first (single source of truth)
    if (currentUser?.hasActiveSubscription == true) {
      return true;
    }

    // For free users, check current usage against limits
    if (currentUser != null) {
      final currentMessages = currentUser!.dailyUsage['messages'] ?? 0;
      return currentMessages < PaymentService.FREE_DAILY_MESSAGES;
    }

    return false; // No user data = no access
  }

  Future<bool> canUploadImage() async {
    if (currentUser?.hasActiveSubscription == true) {
      return true;
    }

    if (currentUser != null) {
      final currentImages = currentUser!.dailyUsage['images'] ?? 0;
      return currentImages < PaymentService.FREE_DAILY_IMAGES;
    }

    return false;
  }

  Future<bool> canSendVoice() async {
    if (currentUser?.hasActiveSubscription == true) {
      return true;
    }

    if (currentUser != null) {
      final currentVoice = currentUser!.dailyUsage['voice'] ?? 0;
      return currentVoice < PaymentService.FREE_DAILY_VOICE;
    }

    return false;
  }

  bool canAccessAllPersonas() {
    // Premium users can access all personas
    return currentUser?.hasActiveSubscription == true;
  }

  // CRITICAL FIX: Usage increment methods with Firestore as primary data store
  Future<void> incrementMessageUsage() async {
    // Don't increment for premium users
    if (currentUser?.hasActiveSubscription == true) return;

    if (currentUser == null) return;

    try {
      // Update local user object
      currentUser = currentUser!.incrementUsage('messages');

      // Save to Firestore (single source of truth)
      await _firestoreService.saveUser(currentUser!);

      // Update payment service for UI consistency
      await _paymentService.incrementMessageCount();

      notifyListeners();
      print(
        '✅ Message usage incremented: ${currentUser!.dailyUsage['messages']}',
      );
    } catch (e) {
      print('❌ Error incrementing message usage: $e');
    }
  }

  Future<void> incrementImageUsage() async {
    if (currentUser?.hasActiveSubscription == true) return;

    if (currentUser == null) return;

    try {
      currentUser = currentUser!.incrementUsage('images');
      await _firestoreService.saveUser(currentUser!);
      await _paymentService.incrementImageCount();

      notifyListeners();
      print('✅ Image usage incremented: ${currentUser!.dailyUsage['images']}');
    } catch (e) {
      print('❌ Error incrementing image usage: $e');
    }
  }

  Future<void> incrementVoiceUsage() async {
    if (currentUser?.hasActiveSubscription == true) return;

    if (currentUser == null) return;

    try {
      currentUser = currentUser!.incrementUsage('voice');
      await _firestoreService.saveUser(currentUser!);
      await _paymentService.incrementVoiceCount();

      notifyListeners();
      print('✅ Voice usage incremented: ${currentUser!.dailyUsage['voice']}');
    } catch (e) {
      print('❌ Error incrementing voice usage: $e');
    }
  }

  // CRITICAL FIX: Get subscription status from Firestore data only
  String _getSubscriptionStatus() {
    if (currentUser?.hasActiveSubscription == true) {
      final type = currentUser!.subscriptionType == 'premium_monthly'
          ? 'Monthly'
          : 'Yearly';
      if (currentUser!.subscriptionExpiryDate != null) {
        final days = currentUser!.daysUntilExpiry;
        if (days > 0) {
          return 'Premium $type ($days days left)';
        } else {
          return 'Premium $type (Expired)';
        }
      }
      return 'Premium $type';
    }
    return 'Free Plan';
  }

  String _getUsageText() {
    if (currentUser?.hasActiveSubscription == true) return 'Unlimited usage';

    if (currentUser != null) {
      final messages = currentUser!.dailyUsage['messages'] ?? 0;
      final images = currentUser!.dailyUsage['images'] ?? 0;
      final voice = currentUser!.dailyUsage['voice'] ?? 0;

      return 'Messages: $messages/${PaymentService.FREE_DAILY_MESSAGES}, '
          'Images: $images/${PaymentService.FREE_DAILY_IMAGES}, '
          'Voice: $voice/${PaymentService.FREE_DAILY_VOICE}';
    }

    return 'No usage data';
  }

  // Generate a unique DiceBear avatar URL
  String _generateAvatarUrl() {
    final seed = DateTime.now().millisecondsSinceEpoch.toString();
    return 'https://api.dicebear.com/7.x/avataaars/svg?seed=$seed';
  }

  Future<bool> signUp(String email, String password, String username) async {
    try {
      _isGoogleSignIn = false;

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? true;
      final uid = userCredential.user?.uid;

      if (uid != null) {
        final newUser = AppUser(
          uid: uid,
          email: email,
          username: username,
          photoUrl: '',
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUser(newUser);
        currentUser = newUser;
        _userPhotoUrl = null;
      }

      user = userCredential.user;
      // Payment service will be initialized by authStateChanges listener
      notifyListeners();

      return isNewUser;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isGoogleSignIn = false;

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user;

      // User data will be loaded by authStateChanges listener
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // CRITICAL FIX: Enhanced logout with complete data cleanup
  Future<void> logout() async {
    try {
      print('🔄 Starting logout process...');

      // CRITICAL: Clear payment service data BEFORE Firebase sign out
      await _paymentService.clearUserData();

      // Sign out from Google if applicable
      if (_isGoogleSignInInitialized) {
        try {
          await _googleSignIn.signOut();
          await _googleSignIn
              .disconnect(); // Also disconnect to clear cached account
        } catch (e) {
          print('⚠️ Google sign out warning: $e');
        }
      }

      // Sign out from Firebase (this will trigger authStateChanges)
      await _auth.signOut();

      print('✅ Logout completed successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _ensureServicesInitialized();

      if (!_googleSignIn.supportsAuthenticate()) {
        throw Exception('Google Sign-In not supported on this platform');
      }

      _isGoogleSignIn = true;

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      _googleSignInAccount = googleUser;

      final authClient = _googleSignIn.authorizationClient;
      final authorization = await authClient.authorizationForScopes(['email']);

      if (authorization == null) {
        throw Exception('Failed to get authorization for required scopes');
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await userCredential.user?.reload();
      user = _auth.currentUser;

      if (user != null) {
        // Check if user exists in Firestore
        currentUser = await _firestoreService.getUser(user!.uid);

        print('🔍 Checking Google user: ${user!.uid}');
        print('🔍 Current user from Firestore: ${currentUser?.uid}');
        print('🔍 Google photo URL: ${user!.photoURL}');

        if (currentUser == null) {
          print('🆕 New Google user - creating profile');

          final String googlePhotoUrl = user!.photoURL ?? '';
          final String googleDisplayName =
              user!.displayName ?? user!.email!.split('@')[0];

          currentUser = AppUser(
            uid: user!.uid,
            email: user!.email!,
            username: googleDisplayName,
            photoUrl: googlePhotoUrl,
            createdAt: DateTime.now(),
          );

          await _firestoreService.saveUser(currentUser!);
          print('✅ New Google user saved');
        } else {
          // Update display name if it has changed
          final String currentGoogleName =
              user!.displayName ?? user!.email!.split('@')[0];
          if (currentUser!.username != currentGoogleName) {
            print('🔄 Updating Google user display name');
            currentUser = currentUser!.copyWith(username: currentGoogleName);
            await _firestoreService.saveUser(currentUser!);
          }
        }

        _userPhotoUrl = currentUser?.photoUrl;
        print('🖼️ User photo URL set to: $_userPhotoUrl');
      }

      notifyListeners();
      print('✅ Google sign-in completed successfully');
    } on GoogleSignInException catch (e) {
      print('❌ Google Sign-In Exception: ${e.code.name} - ${e.description}');
      _isGoogleSignIn = false;
      _googleSignInAccount = null;
      throw Exception(_getGoogleSignInErrorMessage(e));
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      _isGoogleSignIn = false;
      _googleSignInAccount = null;
      throw Exception(e.toString());
    }
  }

  String _getGoogleSignInErrorMessage(GoogleSignInException exception) {
    switch (exception.code.name) {
      case 'canceled':
        return 'Sign-in was cancelled. Please try again if you want to continue.';
      case 'interrupted':
        return 'Sign-in was interrupted. Please try again.';
      case 'clientConfigurationError':
        return 'There is a configuration issue with Google Sign-In. Please contact support.';
      case 'providerConfigurationError':
        return 'Google Sign-In is currently unavailable. Please try again later or contact support.';
      case 'uiUnavailable':
        return 'Google Sign-In is currently unavailable. Please try again later or contact support.';
      case 'userMismatch':
        return 'There was an issue with your account. Please sign out and try again.';
      case 'unknownError':
      default:
        return 'An unexpected error occurred during Google Sign-In. Please try again.';
    }
  }

  bool get isLoggedIn => user != null;
  bool get isGoogleSignIn => _isGoogleSignIn;

  Future<void> uploadUserPhoto(File imageFile) async {
    try {
      if (user == null || currentUser == null) {
        throw Exception('User not authenticated');
      }

      final downloadUrl = await _cloudinaryService.uploadImage(imageFile);

      if (downloadUrl == null) {
        print('❌ Upload failed. No URL returned from Cloudinary.');
        throw Exception('Cloudinary upload failed');
      }

      print('✅ Image uploaded: $downloadUrl');

      currentUser = currentUser!.copyWith(photoUrl: downloadUrl);

      await _firestoreService.saveUser(currentUser!);
      _userPhotoUrl = downloadUrl;

      Fluttertoast.showToast(msg: '✅ Photo uploaded successfully!');
      print('✅ Upload successful: $downloadUrl');

      notifyListeners();
    } catch (e) {
      print('❌ Error uploading user photo: $e');
      Fluttertoast.showToast(msg: '❌ Failed to upload photo');
      throw Exception('Failed to upload photo: ${e.toString()}');
    }
  }

  Future<void> setUserAvatar(String avatarUrl) async {
    try {
      if (user == null || currentUser == null) {
        throw Exception('User not authenticated');
      }

      currentUser = currentUser!.copyWith(photoUrl: avatarUrl);

      await _firestoreService.saveUser(currentUser!);
      _userPhotoUrl = avatarUrl;

      notifyListeners();
    } catch (e) {
      print('Error setting user avatar: $e');
      throw Exception('Failed to set avatar: ${e.toString()}');
    }
  }

  Future<void> loadUserPhoto() async {
    try {
      if (user == null) return;

      final userData = await _firestoreService.getUser(user!.uid);
      if (userData != null) {
        _userPhotoUrl = userData.photoUrl;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user photo: $e');
    }
  }

  bool get hasCompletedProfile {
    if (_isGoogleSignIn) {
      return true;
    } else {
      return _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty;
    }
  }

  Future<bool> checkIfNewUser() async {
    try {
      if (user == null) return false;

      final userData = await _firestoreService.getUser(user!.uid);

      if (_isGoogleSignIn) {
        return userData == null;
      } else {
        return userData == null ||
            userData.photoUrl == null ||
            userData.photoUrl!.isEmpty;
      }
    } catch (e) {
      print('Error checking if new user: $e');
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    } catch (e) {
      throw Exception('Failed to send password reset email');
    }
  }

  bool get needsPhotoUpload {
    if (_isGoogleSignIn) {
      return false;
    } else {
      return !hasCompletedProfile;
    }
  }
}
