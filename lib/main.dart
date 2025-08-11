import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/bootstrap.dart';
import 'config/app_providers.dart';
import 'config/app_router.dart';
import 'providers/themes_provider.dart';
import 'screens/splash_screen.dart';

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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
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
            home: const SplashScreen(),
            routes: buildAppRoutes(),
          );
        },
      ),
    );
  }
}
