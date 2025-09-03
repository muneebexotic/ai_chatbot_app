// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Chatbot';

  @override
  String get settings => 'Settings';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get signIn => 'Sign In';

  @override
  String get signOut => 'Sign out';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get sendMessage => 'Send';

  @override
  String get chatHistory => 'Chat History';

  @override
  String get newChat => 'New Chat';

  @override
  String get accountInformation => 'Account Information';

  @override
  String get appearance => 'Appearance';

  @override
  String get preferences => 'Preferences';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get securitySupport => 'Security & Support';

  @override
  String get errorGeneral => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'Network error. Please check your connection.';

  @override
  String get errorAuth => 'Authentication failed. Please try again.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageChinese => '中文';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get upgradeToPlusTitle => 'Upgrade to Plus';

  @override
  String get upgradeToPlusSubtitle => 'Unlock premium features';

  @override
  String get personalizationTitle => 'Personalization';

  @override
  String get personalizationSubtitle => 'Customize your experience';

  @override
  String get dataControlsTitle => 'Data Controls';

  @override
  String get dataControlsSubtitle => 'Manage your data';

  @override
  String get voiceTitle => 'Voice';

  @override
  String get voiceSubtitle => 'Voice settings and preferences';

  @override
  String get securityTitle => 'Security';

  @override
  String get securitySubtitle => 'Privacy and security settings';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutSubtitle => 'App information and version';

  @override
  String get signOutSubtitle => 'Sign out from your account';

  @override
  String get signOutDialogTitle => 'Sign Out';

  @override
  String get signOutDialogMessage =>
      'Are you sure you want to sign out of your account?';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get lightMode => 'Light mode';

  @override
  String get welcomeBack => 'Welcome';

  @override
  String get backText => 'back';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get login => 'Login';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get createYour => 'Create your';

  @override
  String get account => 'account';

  @override
  String get fullName => 'Full Name';

  @override
  String get fullNameHint => 'Enter your full name';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get exitApp => 'Exit App?';

  @override
  String get exitAppMessage => 'Are you sure you want to exit the app?';

  @override
  String get conversationsSaved =>
      'Your conversations will be saved and available when you return.';

  @override
  String get exit => 'Exit';

  @override
  String get howCanIHelp => 'How can I help you today?';

  @override
  String get chooseTopicOrType =>
      'Choose a topic below or start typing your question';

  @override
  String get quickSuggestions => 'Quick Suggestions';

  @override
  String get dailyUsage => 'Daily Usage';

  @override
  String get generateImage => 'Generate Image';

  @override
  String get describeWhatYouWant => 'Describe what you want to create:';

  @override
  String get imagePromptHint =>
      'e.g., A beautiful sunset over mountains, digital art style';

  @override
  String get imagePromptTip =>
      'Be specific! Include style, mood, colors, and details for better results.';

  @override
  String get generate => 'Generate';

  @override
  String get voiceLimitReached => 'Voice Limit Reached';

  @override
  String get messageLimitReached => 'Message Limit Reached';

  @override
  String get imageLimitReached => 'Image Generation Limit Reached';

  @override
  String upgradeForUnlimited(String feature) {
    return 'Upgrade to Premium for unlimited $feature!';
  }

  @override
  String get premiumBenefits => 'Premium Benefits:';

  @override
  String get unlimitedMessages => '• Unlimited messages';

  @override
  String get unlimitedImagesVoice => '• Unlimited images & voice';

  @override
  String get allPersonasUnlocked => '• All personas unlocked';

  @override
  String get prioritySupport => '• Priority support';

  @override
  String get later => 'Later';

  @override
  String get upgradeNow => 'Upgrade Now';

  @override
  String get microphoneNotAvailable => 'Microphone not available';

  @override
  String failedToSendMessage(String error) {
    return 'Failed to send message: $error';
  }

  @override
  String failedToGenerateImage(String error) {
    return 'Failed to generate image: $error';
  }
}
