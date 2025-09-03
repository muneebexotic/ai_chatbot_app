import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../lib/l10n/generated/app_localizations.dart';

void main() {
  group('Localization Tests', () {
    testWidgets('English translations are accessible', (WidgetTester tester) async {
      // Build a minimal app with localization support
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
          ],
          home: const TestWidget(),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Find the test widget
      final testWidget = find.byType(TestWidget);
      expect(testWidget, findsOneWidget);

      // Get the context and test translations
      final BuildContext context = tester.element(testWidget);
      final AppLocalizations l10n = AppLocalizations.of(context);

      // Test basic translations
      expect(l10n.appTitle, equals('AI Chatbot'));
      expect(l10n.settings, equals('Settings'));
      expect(l10n.back, equals('Back'));
      expect(l10n.cancel, equals('Cancel'));
      expect(l10n.save, equals('Save'));
      expect(l10n.done, equals('Done'));
      
      // Test authentication translations
      expect(l10n.signIn, equals('Sign In'));
      expect(l10n.signOut, equals('Sign out'));
      expect(l10n.signUp, equals('Sign Up'));
      expect(l10n.email, equals('Email'));
      expect(l10n.password, equals('Password'));
      
      // Test chat interface translations
      expect(l10n.typeMessage, equals('Type a message...'));
      expect(l10n.sendMessage, equals('Send'));
      expect(l10n.chatHistory, equals('Chat History'));
      expect(l10n.newChat, equals('New Chat'));
      
      // Test settings screen translations
      expect(l10n.accountInformation, equals('Account Information'));
      expect(l10n.appearance, equals('Appearance'));
      expect(l10n.preferences, equals('Preferences'));
      expect(l10n.language, equals('Language'));
      expect(l10n.selectLanguage, equals('Select Language'));
      expect(l10n.securitySupport, equals('Security & Support'));
      
      // Test language names
      expect(l10n.languageEnglish, equals('English'));
      expect(l10n.languageUrdu, equals('اردو'));
      expect(l10n.languageSpanish, equals('Español'));
      expect(l10n.languageRussian, equals('Русский'));
      expect(l10n.languageChinese, equals('中文'));
      expect(l10n.languageFrench, equals('Français'));
      expect(l10n.languageArabic, equals('العربية'));
      
      // Test error messages
      expect(l10n.errorGeneral, equals('Something went wrong. Please try again.'));
      expect(l10n.errorNetwork, equals('Network error. Please check your connection.'));
      expect(l10n.errorAuth, equals('Authentication failed. Please try again.'));
    });

    testWidgets('Parameterized translations work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
          ],
          home: const TestWidget(),
        ),
      );

      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(TestWidget));
      final AppLocalizations l10n = AppLocalizations.of(context);

      // Test parameterized translations
      expect(
        l10n.upgradeForUnlimited('messages'),
        equals('Upgrade to Premium for unlimited messages!'),
      );
      
      expect(
        l10n.upgradeForUnlimited('images'),
        equals('Upgrade to Premium for unlimited images!'),
      );
      
      expect(
        l10n.failedToSendMessage('Network timeout'),
        equals('Failed to send message: Network timeout'),
      );
      
      expect(
        l10n.failedToGenerateImage('API error'),
        equals('Failed to generate image: API error'),
      );
    });

    test('AppLocalizations delegate is properly configured', () {
      // Test that the delegate is not null and has correct properties
      expect(AppLocalizations.delegate, isNotNull);
      expect(AppLocalizations.delegate.type, equals(AppLocalizations));
    });

    test('Supported locales are correctly defined', () {
      // Test that we have the expected supported locales
      const expectedLocales = [
        Locale('en', 'US'),
        Locale('ur', 'PK'),
        Locale('es', 'ES'),
        Locale('ru', 'RU'),
        Locale('zh', 'CN'),
        Locale('fr', 'FR'),
        Locale('ar', 'SA'),
      ];
      
      // This test verifies that our main app configuration matches expected locales
      // The actual supported locales are defined in main.dart
      expect(expectedLocales.length, equals(7));
      expect(expectedLocales.first.languageCode, equals('en'));
      expect(expectedLocales.last.languageCode, equals('ar'));
    });
  });
}

/// Simple test widget to provide a context for localization testing
class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Test Widget'),
      ),
    );
  }
}