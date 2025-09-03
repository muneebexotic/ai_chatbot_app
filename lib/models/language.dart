import 'package:flutter/material.dart';

class Language {
  final String code;
  final String countryCode;
  final String nativeName;
  final String englishName;
  final bool isRTL;

  const Language({
    required this.code,
    required this.countryCode,
    required this.nativeName,
    required this.englishName,
    required this.isRTL,
  });

  Locale get locale => Locale(code, countryCode);

  static const List<Language> supportedLanguages = [
    Language(
      code: 'en',
      countryCode: 'US',
      nativeName: 'English',
      englishName: 'English',
      isRTL: false,
    ),
    Language(
      code: 'ur',
      countryCode: 'PK',
      nativeName: 'اردو',
      englishName: 'Urdu',
      isRTL: true,
    ),
    Language(
      code: 'es',
      countryCode: 'ES',
      nativeName: 'Español',
      englishName: 'Spanish',
      isRTL: false,
    ),
    Language(
      code: 'ru',
      countryCode: 'RU',
      nativeName: 'Русский',
      englishName: 'Russian',
      isRTL: false,
    ),
    Language(
      code: 'zh',
      countryCode: 'CN',
      nativeName: '中文',
      englishName: 'Chinese',
      isRTL: false,
    ),
    Language(
      code: 'fr',
      countryCode: 'FR',
      nativeName: 'Français',
      englishName: 'French',
      isRTL: false,
    ),
    Language(
      code: 'ar',
      countryCode: 'SA',
      nativeName: 'العربية',
      englishName: 'Arabic',
      isRTL: true,
    ),
  ];

  static Language? getLanguageByLocale(Locale locale) {
    try {
      return supportedLanguages.firstWhere(
        (lang) => lang.code == locale.languageCode,
      );
    } catch (e) {
      return null;
    }
  }

  static Language get defaultLanguage => supportedLanguages.first; // English

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          countryCode == other.countryCode;

  @override
  int get hashCode => code.hashCode ^ countryCode.hashCode;

  @override
  String toString() => '$nativeName ($englishName)';
}