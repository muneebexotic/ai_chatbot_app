import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? user;

  AuthProvider() {
    user = _auth.currentUser;
    _auth.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
  }

  // 🔐 Email/Password Sign-Up
  Future<void> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    user = cred.user;
    notifyListeners();
  }

  // 🔑 Email/Password Login
  Future<void> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    user = cred.user;
    notifyListeners();
  }

  // 🔓 Logout from Firebase and Google
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut(); // also logout from Google
    user = null;
    notifyListeners();
  }

  // 🔐 Google Sign-In
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // Cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      user = userCredential.user;
      notifyListeners();
    } catch (e) {
      rethrow; // Let the UI handle error messages
    }
  }

  bool get isLoggedIn => user != null;
}
