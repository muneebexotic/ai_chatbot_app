import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/ui/app_messenger.dart';
import 'config/bootstrap.dart';
import 'config/app_router.dart';
import 'providers/themes_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/app_theme.dart'; 
import 'screens/splash_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/welcome_screen.dart';
import 'app/providers.dart';

Future<void> main() async {
  // Ensure Flutter is initialized and preserve native splash
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Initialize app
  await AppBootstrap.initialize();
  
  // ProviderScope replaces MultiProvider as the root of the dependency graph
  // (PRD F5). Providers themselves are declared in lib/app/providers.dart
  // rather than assembled here, so the graph is readable in one place and
  // usable from tests via ProviderContainer.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeNotifierProvider);
    final authProvider = ref.watch(authNotifierProvider);

    return MaterialApp(
      title: 'AI Chatbot',
      debugShowCheckedModeBanner: false,
      // Lets non-widget code surface a message without holding a
      // BuildContext (PRD §9.1). Without this key every AppMessenger
      // call is a silent no-op.
      scaffoldMessengerKey: AppMessenger.key,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: _buildInitialScreen(authProvider, themeProvider),
      routes: buildAppRoutes(),
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) =>
              authProvider.isLoggedIn ? const ChatScreen() : const WelcomeScreen(),
        );
      },
    );
  }

  Widget _buildInitialScreen(AuthProvider authProvider, ThemeProvider themeProvider) {
    // Remove native splash after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    
    return const SplashScreen();
  }
}