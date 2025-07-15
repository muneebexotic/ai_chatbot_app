import 'package:ai_chatbot_app/providers/conversation_provider.dart';
import 'package:ai_chatbot_app/providers/settings_provider.dart';
import 'package:ai_chatbot_app/screens/forgot_password_screen.dart';
import 'package:ai_chatbot_app/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/themes_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // 🔄 ConversationsProvider - depends on AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ConversationsProvider>(
          create: (_) => ConversationsProvider(userId: ''),
          update: (_, auth, previous) {
            final userId = auth.user?.uid ?? '';
            return ConversationsProvider(userId: userId);
          },
        ),

        // 💬 ChatProvider - depends on AuthProvider and SettingsProvider
        ChangeNotifierProxyProvider2<AuthProvider, SettingsProvider, ChatProvider>(
          create: (context) => ChatProvider(userId: '', context: context),
          update: (context, auth, settings, previous) {
            final userId = auth.user?.uid ?? '';
            return ChatProvider(userId: userId, context: context);
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AI Chatbot',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/chat': (_) => const ChatScreen(),
              '/signup': (_) => const SignUpScreen(),
              '/welcome': (_) => const WelcomeScreen(),
              '/forgot-password': (_) => const ForgotPasswordScreen(),
            },
          );
        },
      ),
    );
  }
}
