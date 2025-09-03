import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'config/bootstrap.dart';
import 'config/app_providers.dart';
import 'config/app_router.dart';
import 'providers/themes_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/localization_provider.dart';
import 'utils/app_theme.dart'; 
import 'screens/splash_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  // Ensure Flutter is initialized and preserve native splash
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Initialize app
  await AppBootstrap.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: Consumer3<ThemeProvider, AuthProvider, LocalizationProvider>(
        builder: (context, themeProvider, authProvider, localizationProvider, _) {
          return Directionality(
            textDirection: localizationProvider.textDirection,
            child: MaterialApp(
              title: 'AI Chatbot',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              locale: localizationProvider.currentLocale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: LocalizationProvider.supportedLocales,
              localeResolutionCallback: (locale, supportedLocales) {
                // If the device locale is supported, use it
                if (locale != null) {
                  for (var supportedLocale in supportedLocales) {
                    if (supportedLocale.languageCode == locale.languageCode) {
                      return supportedLocale;
                    }
                  }
                }
                // Fallback to English if device locale is not supported
                return const Locale('en', 'US');
              },
              home: _buildInitialScreen(authProvider, themeProvider),
              routes: buildAppRoutes(),
              onUnknownRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => authProvider.isLoggedIn 
                    ? const ChatScreen() 
                    : const WelcomeScreen(),
                );
              },
            ),
          );
        },
      ),
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