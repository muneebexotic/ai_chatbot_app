import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/bootstrap.dart';
import 'config/app_providers.dart';
import 'config/app_router.dart';
import 'providers/themes_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  await AppBootstrap.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          return MaterialApp(
            title: 'AI Chatbot',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light().copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: _buildInitialScreen(authProvider),
            routes: buildAppRoutes(),
            // CRITICAL: Handle unknown routes
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => authProvider.isLoggedIn 
                  ? const ChatScreen() 
                  : const WelcomeScreen(),
              );
            },
          );
        },
      ),
    );
  }

  // CRITICAL FIX: Determine initial screen based on auth state
  Widget _buildInitialScreen(AuthProvider authProvider) {
    // If auth provider is not initialized yet, show splash
    if (!authProvider.isInitialized) {
      return const SplashScreen();
    }
    
    // If user is logged in, go directly to chat
    if (authProvider.isLoggedIn) {
      return const ChatScreen();
    }
    
    // Otherwise, show splash which will handle navigation
    return const SplashScreen();
  }
}