// All app routes

import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/login_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/memory/presentation/memory_screen.dart';
import '../features/session/presentation/session_home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/subscription_screen.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/welcome': (_) => const WelcomeScreen(),
    '/signup': (_) => const SignUpScreen(),
    '/login': (_) => const LoginScreen(),
    '/forgot-password': (_) => const ForgotPasswordScreen(),
    // §4: "A Session is a live spoken conversation with an AI partner... It is
    // the app's reason to exist and its highest-value screen. Build it as the
    // centre of the product, not as a mode hidden behind a microphone icon."
    // So it is a route of its own, and it is where a signed-in user lands.
    '/session': (_) => const SessionHomeScreen(),
    '/chat': (_) => const ChatScreen(),
    '/memory': (_) => const MemoryScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/subscription': (_) => const SubscriptionScreen(),
  };
}
