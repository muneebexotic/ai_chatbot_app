import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/bootstrap.dart';
import 'config/app_providers.dart';
import 'config/app_router.dart';
import 'providers/themes_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/app_theme.dart'; 
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
            // Use your custom themes instead of default ones
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: _buildInitialScreen(authProvider),
            routes: buildAppRoutes(),
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

  Widget _buildInitialScreen(AuthProvider authProvider) {
    if (!authProvider.isInitialized) {
      return const SplashScreen();
    }
    
    if (authProvider.isLoggedIn) {
      return const ChatScreen();
    }
    
    return const SplashScreen();
  }
}