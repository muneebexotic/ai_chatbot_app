import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  User? user;
  AppUser? currentUser;
  bool _isGoogleSignIn = false; // Track if it's Google sign-in

  String get displayName => currentUser?.username ?? "User";
  String? _userPhotoUrl;
  String? get userPhotoUrl => _userPhotoUrl ?? currentUser?.photoUrl;

  AuthProvider() {
    user = _auth.currentUser;
    _auth.authStateChanges().listen((u) async {
      user = u;
      if (user != null) {
        print('✅ Firebase user detected: ${user!.uid}');
        currentUser = await _firestoreService.getUser(user!.uid);
        print('✅ Firestore user loaded: ${currentUser?.uid}');
        _userPhotoUrl = currentUser?.photoUrl;
      } else {
        print('👋 User signed out or null');
        currentUser = null;
        _userPhotoUrl = null;
        _isGoogleSignIn = false;
      }
      notifyListeners();
    });
  }

  // Generate a unique DiceBear avatar URL
  String _generateAvatarUrl() {
    final seed = DateTime.now().millisecondsSinceEpoch.toString();
    return 'https://api.dicebear.com/7.x/avataaars/svg?seed=$seed';
  }

  Future<bool> signUp(String email, String password, String username) async {
    try {
      _isGoogleSignIn = false; // Mark as manual signup
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? true;
      final uid = userCredential.user?.uid;
      
      if (uid != null) {
        // For manual signup, don't generate avatar - let them upload one
        final newUser = AppUser(
          uid: uid,
          email: email,
          username: username,
          photoUrl: '', // Empty for manual signup to trigger photo upload screen
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveUser(newUser);
        currentUser = newUser;
        _userPhotoUrl = null; // Ensure it's null to trigger photo upload
      }

      user = userCredential.user;
      notifyListeners();

      return isNewUser;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isGoogleSignIn = false; // Mark as manual login
      
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user;

      if (user != null) {
        currentUser = await _firestoreService.getUser(user!.uid);
        _userPhotoUrl = currentUser?.photoUrl;
      }
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      user = null;
      currentUser = null;
      _userPhotoUrl = null;
      _isGoogleSignIn = false;
      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _isGoogleSignIn = true; // Mark as Google sign-in
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isGoogleSignIn = false;
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
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

        // If new Google user, create with Google's photo URL (or empty)
        if (currentUser == null) {
          print('🆕 New Google user - using Google avatar');
          
          // Use Google's provided photo URL (includes auto-generated letter avatars)
          final String googlePhotoUrl = user!.photoURL ?? '';
          final String googleDisplayName = user!.displayName ?? user!.email!.split('@')[0];
          
          print('🎭 Google photo URL: $googlePhotoUrl');
          print('👤 Google display name: $googleDisplayName');

          currentUser = AppUser(
            uid: user!.uid,
            email: user!.email!,
            username: googleDisplayName, // Use Google's display name
            photoUrl: googlePhotoUrl, // Use Google's avatar (letter avatar or actual photo)
            createdAt: DateTime.now(),
          );

          await _firestoreService.saveUser(currentUser!);
          print('✅ New Google user saved with Google avatar and name');
        } else {
          // For existing Google users, update the display name if it has changed
          final String currentGoogleName = user!.displayName ?? user!.email!.split('@')[0];
          if (currentUser!.username != currentGoogleName) {
            print('🔄 Updating Google user display name from "${currentUser!.username}" to "$currentGoogleName"');
            currentUser = AppUser(
              uid: currentUser!.uid,
              email: currentUser!.email,
              username: currentGoogleName, // Update to current Google display name
              photoUrl: currentUser!.photoUrl,
              createdAt: currentUser!.createdAt,
            );
            await _firestoreService.saveUser(currentUser!);
          }
        }

        // Ensure _userPhotoUrl is updated
        _userPhotoUrl = currentUser?.photoUrl;
        print('🖼️ User photo URL set to: $_userPhotoUrl');
      }

      notifyListeners();
      print('✅ Google sign-in completed successfully');
      
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      _isGoogleSignIn = false;
      throw Exception(e.toString());
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

      currentUser = AppUser(
        uid: currentUser!.uid,
        email: currentUser!.email,
        username: currentUser!.username,
        photoUrl: downloadUrl,
        createdAt: currentUser!.createdAt,
      );

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

      currentUser = AppUser(
        uid: currentUser!.uid,
        email: currentUser!.email,
        username: currentUser!.username,
        photoUrl: avatarUrl,
        createdAt: currentUser!.createdAt,
      );

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

  // Updated logic: Google users always have avatars (from Google), manual users need upload
  bool get hasCompletedProfile {
    if (_isGoogleSignIn) {
      // Google users always have a profile (Google provides letter avatars even without photos)
      return true; // Google users don't need photo upload
    } else {
      // Manual signup users need to upload a photo
      return _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty;
    }
  }

  Future<bool> checkIfNewUser() async {
    try {
      if (user == null) return false;

      final userData = await _firestoreService.getUser(user!.uid);
      
      if (_isGoogleSignIn) {
        // For Google users, they're "new" if they don't exist in Firestore
        // But once created, they should have an avatar automatically
        return userData == null;
      } else {
        // For manual users, they're "new" if no photo is uploaded
        return userData == null || userData.photoUrl == null || userData.photoUrl!.isEmpty;
      }
    } catch (e) {
      print('Error checking if new user: $e');
      return false;
    }
  }

  // Helper method to check if user needs photo upload screen
  bool get needsPhotoUpload {
    if (_isGoogleSignIn) {
      return false; // Google users don't need photo upload screen
    } else {
      return !hasCompletedProfile; // Manual users need it if no photo
    }
  }
}