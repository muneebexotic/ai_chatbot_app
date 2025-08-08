import 'package:ai_chatbot_app/screens/photo_upload_screen.dart';
import 'package:ai_chatbot_app/screens/settings_screen.dart';
import 'package:ai_chatbot_app/screens/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
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
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core providers
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        
        // Auth provider (initializes payment service)
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        
        // Settings provider with initialization
        ChangeNotifierProvider(
          create: (_) {
            final settingsProvider = SettingsProvider();
            // Initialize settings in background
            WidgetsBinding.instance.addPostFrameCallback((_) {
              settingsProvider.initializeSettings();
            });
            return settingsProvider;
          },
        ),

        // ConversationsProvider depends on AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, ConversationsProvider>(
          create: (_) => ConversationsProvider(userId: ''),
          update: (_, auth, previous) {
            final userId = auth.user?.uid ?? '';
            
            // Only create new provider if userId changed
            if (previous?.userId != userId) {
              return ConversationsProvider(userId: userId);
            }
            
            // Update existing provider's userId if needed
            if (previous != null) {
              previous.updateUserId(userId);
              return previous;
            }
            
            return ConversationsProvider(userId: userId);
          },
        ),

        // ChatProvider depends on Auth and Settings
        ChangeNotifierProxyProvider2<AuthProvider, SettingsProvider, ChatProvider>(
          create: (context) => ChatProvider(userId: '', context: context),
          update: (context, auth, settings, previous) {
            final userId = auth.user?.uid ?? '';
            
            // Only create new provider if userId changed
            if (previous?.userId != userId) {
              return ChatProvider(userId: userId, context: context);
            }
            
            // Return existing provider if userId is same
            return previous ?? ChatProvider(userId: userId, context: context);
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AI Chatbot',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light().copyWith(
              // Customize light theme if needed
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              // Customize dark theme if needed
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/welcome': (_) => const WelcomeScreen(),
              '/signup': (_) => const SignUpScreen(),
              '/login': (_) => const LoginScreen(),
              '/forgot-password': (_) => const ForgotPasswordScreen(),
              '/chat': (_) => const ChatScreen(),
              '/photo-upload': (_) => const PhotoUploadScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/subscription': (_) => const SubscriptionScreen(),
            },
            // Global error handling
            builder: (context, child) {
              // Handle global errors and ensure proper widget tree
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                return MaterialApp(
                  home: Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Something went wrong',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please restart the app',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              };
              
              return child!;
            },
          );
        },
      ),
    );
  }
}

// Global error handler for the app
class AppErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log error to console in debug mode
      FlutterError.presentError(details);
      
      // In production, you might want to send to crashlytics
      // FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
  }
}