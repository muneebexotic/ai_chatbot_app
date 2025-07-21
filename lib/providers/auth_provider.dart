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
      }
      notifyListeners();
    });
  }

  Future<bool> signUp(String email, String password, String username) async {
    try {
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
      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

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
        currentUser = await _firestoreService.getUser(user!.uid);

        if (currentUser == null) {
          currentUser = AppUser(
            uid: user!.uid,
            email: user!.email!,
            username: user!.displayName ?? user!.email!.split('@')[0],
            photoUrl: user!.photoURL,
            createdAt: DateTime.now(),
          );
          await _firestoreService.saveUser(currentUser!);
        }

        _userPhotoUrl = currentUser?.photoUrl;
      }
      notifyListeners();
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      throw Exception(e.toString());
    }
  }

  bool get isLoggedIn => user != null;

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

  bool get hasCompletedProfile =>
      _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty;

  Future<bool> checkIfNewUser() async {
    try {
      if (user == null) return false;

      final userData = await _firestoreService.getUser(user!.uid);
      return userData == null || userData.photoUrl == null || userData.photoUrl!.isEmpty;
    } catch (e) {
      print('Error checking if new user: $e');
      return false;
    }
  }
}
