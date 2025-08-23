// All app routes

import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/login_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/photo_upload_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/subscription_screen.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/welcome': (_) => const WelcomeScreen(),
    '/signup': (_) => const SignUpScreen(),
    '/login': (_) => const LoginScreen(),
    '/forgot-password': (_) => const ForgotPasswordScreen(),
    '/chat': (_) => const ChatScreen(),
    '/photo-upload': (_) => const PhotoUploadScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/subscription': (_) => const SubscriptionScreen(),
  };
}
