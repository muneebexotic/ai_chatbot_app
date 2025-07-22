import 'package:ai_chatbot_app/screens/photo_upload_screen';
import 'package:ai_chatbot_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/themes_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/settings_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/chat_screen.dart';


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

        /// ConversationsProvider depends on AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ConversationsProvider>(
          create: (_) => ConversationsProvider(userId: ''),
          update: (_, auth, __) {
            final userId = auth.user?.uid ?? '';
            return ConversationsProvider(userId: userId);
          },
        ),

        /// ChatProvider depends on Auth and Settings
        ChangeNotifierProxyProvider2<AuthProvider, SettingsProvider, ChatProvider>(
          create: (context) => ChatProvider(userId: '', context: context),
          update: (context, auth, settings, __) {
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
            home: const SplashScreen(), // 👈 set splash screen here
            routes: {
              '/welcome': (_) => const WelcomeScreen(),
              '/signup': (_) => const SignUpScreen(),
              '/login': (_) => const LoginScreen(),
              '/forgot-password': (_) => const ForgotPasswordScreen(),
              '/chat': (_) => const ChatScreen(),
              '/photo-upload': (_) => const PhotoUploadScreen(),
              '/settings': (_) => const SettingsScreen()
            
            },
          );
        },
      ),
    );
  }
}
