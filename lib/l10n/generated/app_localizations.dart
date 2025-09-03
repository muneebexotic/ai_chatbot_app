import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'AI Chatbot'**
  String get appTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Back button text
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Done button text
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign out button text
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Sign up button text
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Placeholder text for message input field
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// Send message button text
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendMessage;

  /// Chat history section title
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get chatHistory;

  /// New chat button text
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// Account information section title
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// Appearance section title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Preferences section title
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Language setting option
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Security and support section title
  ///
  /// In en, this message translates to:
  /// **'Security & Support'**
  String get securitySupport;

  /// General error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneral;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetwork;

  /// Authentication error message
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get errorAuth;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Urdu language name in native script
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get languageUrdu;

  /// Spanish language name in native script
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// Russian language name in native script
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// Chinese language name in native script
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// French language name in native script
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// Arabic language name in native script
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// Phone number field label
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// Upgrade to Plus option title
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Plus'**
  String get upgradeToPlusTitle;

  /// Upgrade to Plus option subtitle
  ///
  /// In en, this message translates to:
  /// **'Unlock premium features'**
  String get upgradeToPlusSubtitle;

  /// Personalization option title
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get personalizationTitle;

  /// Personalization option subtitle
  ///
  /// In en, this message translates to:
  /// **'Customize your experience'**
  String get personalizationSubtitle;

  /// Data controls option title
  ///
  /// In en, this message translates to:
  /// **'Data Controls'**
  String get dataControlsTitle;

  /// Data controls option subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage your data'**
  String get dataControlsSubtitle;

  /// Voice settings option title
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceTitle;

  /// Voice settings option subtitle
  ///
  /// In en, this message translates to:
  /// **'Voice settings and preferences'**
  String get voiceSubtitle;

  /// Security option title
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// Security option subtitle
  ///
  /// In en, this message translates to:
  /// **'Privacy and security settings'**
  String get securitySubtitle;

  /// About option title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// About option subtitle
  ///
  /// In en, this message translates to:
  /// **'App information and version'**
  String get aboutSubtitle;

  /// Sign out option subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign out from your account'**
  String get signOutSubtitle;

  /// Sign out confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutDialogTitle;

  /// Sign out confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out of your account?'**
  String get signOutDialogMessage;

  /// Dark mode setting text
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// Light mode setting text
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// Welcome back text on login screen
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeBack;

  /// Second part of welcome back text
  ///
  /// In en, this message translates to:
  /// **'back'**
  String get backText;

  /// Email input field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// Password input field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Sign up prompt text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// Social login divider text
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// First part of sign up header
  ///
  /// In en, this message translates to:
  /// **'Create your'**
  String get createYour;

  /// Second part of sign up header
  ///
  /// In en, this message translates to:
  /// **'account'**
  String get account;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Full name input field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get fullNameHint;

  /// Login prompt text on sign up screen
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// Exit app dialog title
  ///
  /// In en, this message translates to:
  /// **'Exit App?'**
  String get exitApp;

  /// Exit app dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get exitAppMessage;

  /// Exit app dialog info message
  ///
  /// In en, this message translates to:
  /// **'Your conversations will be saved and available when you return.'**
  String get conversationsSaved;

  /// Exit button text
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// Chat screen welcome message
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get howCanIHelp;

  /// Chat screen instruction text
  ///
  /// In en, this message translates to:
  /// **'Choose a topic below or start typing your question'**
  String get chooseTopicOrType;

  /// Suggestions modal title
  ///
  /// In en, this message translates to:
  /// **'Quick Suggestions'**
  String get quickSuggestions;

  /// Daily usage section title
  ///
  /// In en, this message translates to:
  /// **'Daily Usage'**
  String get dailyUsage;

  /// Generate image dialog title
  ///
  /// In en, this message translates to:
  /// **'Generate Image'**
  String get generateImage;

  /// Image generation prompt instruction
  ///
  /// In en, this message translates to:
  /// **'Describe what you want to create:'**
  String get describeWhatYouWant;

  /// Image generation prompt hint text
  ///
  /// In en, this message translates to:
  /// **'e.g., A beautiful sunset over mountains, digital art style'**
  String get imagePromptHint;

  /// Image generation tip text
  ///
  /// In en, this message translates to:
  /// **'Be specific! Include style, mood, colors, and details for better results.'**
  String get imagePromptTip;

  /// Generate button text
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// Voice limit reached dialog title
  ///
  /// In en, this message translates to:
  /// **'Voice Limit Reached'**
  String get voiceLimitReached;

  /// Message limit reached dialog title
  ///
  /// In en, this message translates to:
  /// **'Message Limit Reached'**
  String get messageLimitReached;

  /// Image limit reached dialog title
  ///
  /// In en, this message translates to:
  /// **'Image Generation Limit Reached'**
  String get imageLimitReached;

  /// Upgrade prompt message
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium for unlimited {feature}!'**
  String upgradeForUnlimited(String feature);

  /// Premium benefits section title
  ///
  /// In en, this message translates to:
  /// **'Premium Benefits:'**
  String get premiumBenefits;

  /// Premium benefit: unlimited messages
  ///
  /// In en, this message translates to:
  /// **'• Unlimited messages'**
  String get unlimitedMessages;

  /// Premium benefit: unlimited images and voice
  ///
  /// In en, this message translates to:
  /// **'• Unlimited images & voice'**
  String get unlimitedImagesVoice;

  /// Premium benefit: all personas unlocked
  ///
  /// In en, this message translates to:
  /// **'• All personas unlocked'**
  String get allPersonasUnlocked;

  /// Premium benefit: priority support
  ///
  /// In en, this message translates to:
  /// **'• Priority support'**
  String get prioritySupport;

  /// Later button text
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// Upgrade now button text
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get upgradeNow;

  /// Microphone not available error message
  ///
  /// In en, this message translates to:
  /// **'Microphone not available'**
  String get microphoneNotAvailable;

  /// Failed to send message error
  ///
  /// In en, this message translates to:
  /// **'Failed to send message: {error}'**
  String failedToSendMessage(String error);

  /// Failed to generate image error
  ///
  /// In en, this message translates to:
  /// **'Failed to generate image: {error}'**
  String failedToGenerateImage(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
