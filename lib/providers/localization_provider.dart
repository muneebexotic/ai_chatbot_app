import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language.dart';

class LocalizationProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en', 'US');
  static const String _localeKey = 'selected_locale';

  // Supported locales based on Language model
  static final List<Locale> supportedLocales = Language.supportedLanguages
      .map((language) => language.locale)
      .toList();

  Locale get currentLocale => _currentLocale;
  
  /// Returns true if the current locale uses right-to-left text direction
  bool get isRTL {
    return _currentLocale.languageCode == 'ar' || 
           _currentLocale.languageCode == 'ur';
  }

  /// Returns the current language object
  Language get currentLanguage {
    return Language.getLanguageByLocale(_currentLocale) ?? 
           Language.defaultLanguage;
  }

  /// Returns the text direction for the current locale
  TextDirection get textDirection {
    return isRTL ? TextDirection.rtl : TextDirection.ltr;
  }

  LocalizationProvider() {
    _loadLocale();
  }

  /// Sets the locale and persists the preference
  Future<void> setLocale(Locale locale) async {
    if (_isLocaleSupported(locale)) {
      if (_currentLocale.languageCode != locale.languageCode || 
          _currentLocale.countryCode != locale.countryCode) {
        _currentLocale = locale;
        await _saveLocale();
        notifyListeners();
      }
    }
  }

  /// Sets the language using Language object
  Future<void> setLanguage(Language language) async {
    await setLocale(language.locale);
  }

  /// Checks if a locale is supported
  bool _isLocaleSupported(Locale locale) {
    return supportedLocales.any((supportedLocale) =>
        supportedLocale.languageCode == locale.languageCode &&
        supportedLocale.countryCode == locale.countryCode);
  }

  /// Loads the saved locale preference
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeString = prefs.getString(_localeKey);
      
      if (localeString != null) {
        final parts = localeString.split('_');
        if (parts.length == 2) {
          final locale = Locale(parts[0], parts[1]);
          if (_isLocaleSupported(locale)) {
            _currentLocale = locale;
            notifyListeners();
            return;
          }
        }
      }
      
      // If no saved preference or invalid, try device locale
      _setDeviceLocaleOrDefault();
    } catch (e) {
      debugPrint('Failed to load locale preference: $e');
      _setDeviceLocaleOrDefault();
    }
  }

  /// Sets device locale if supported, otherwise defaults to English
  void _setDeviceLocaleOrDefault() {
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    
    // Check if device locale is supported (match by language code only for device locale)
    Locale? supportedDeviceLocale;
    try {
      supportedDeviceLocale = supportedLocales.firstWhere(
        (locale) => locale.languageCode == deviceLocale.languageCode,
      );
    } catch (e) {
      supportedDeviceLocale = const Locale('en', 'US'); // Default to English
    }
    
    _currentLocale = supportedDeviceLocale;
    notifyListeners();
  }

  /// Saves the current locale preference
  Future<void> _saveLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeString = '${_currentLocale.languageCode}_${_currentLocale.countryCode}';
      await prefs.setString(_localeKey, localeString);
    } catch (e) {
      debugPrint('Failed to save locale preference: $e');
    }
  }

  /// Resets to default language (English)
  Future<void> resetToDefault() async {
    await setLocale(Language.defaultLanguage.locale);
  }

  /// Gets all supported languages
  List<Language> getSupportedLanguages() {
    return Language.supportedLanguages;
  }
}