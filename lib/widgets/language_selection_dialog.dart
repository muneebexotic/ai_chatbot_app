import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../providers/themes_provider.dart';
import '../providers/localization_provider.dart';
import '../components/ui/app_text.dart';
import '../models/language.dart';
import '../l10n/generated/app_localizations.dart';

class LanguageSelectionDialog extends StatelessWidget {
  const LanguageSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocalizationProvider>(
      builder: (context, themeProvider, localizationProvider, child) {
        final isDark = themeProvider.isDark;
        final currentLocale = localizationProvider.currentLocale;
        
        return AlertDialog(
          backgroundColor: AppColors.getSurface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText.titleLarge(
                  AppLocalizations.of(context).selectLanguage,
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText.bodyMedium(
                  'Choose your preferred language',
                  color: AppColors.getTextSecondary(isDark),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      children: Language.supportedLanguages.map((language) {
                        final isSelected = language.locale.languageCode == currentLocale.languageCode;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.getSurfaceVariant(isDark).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppColors.primary.withOpacity(0.2)
                                    : AppColors.getSurfaceVariant(isDark).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  _getLanguageFlag(language.code),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            title: AppText.titleMedium(
                              language.nativeName,
                              color: AppColors.getTextPrimary(isDark),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            subtitle: language.nativeName != language.englishName
                                ? AppText.bodySmall(
                                    language.englishName,
                                    color: AppColors.getTextSecondary(isDark),
                                  )
                                : null,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  )
                                : null,
                            onTap: () {
                              localizationProvider.setLocale(language.locale);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText.bodyMedium(
                AppLocalizations.of(context).cancel,
                color: AppColors.getTextSecondary(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸';
      case 'ur':
        return '🇵🇰';
      case 'es':
        return '🇪🇸';
      case 'ru':
        return '🇷🇺';
      case 'zh':
        return '🇨🇳';
      case 'fr':
        return '🇫🇷';
      case 'ar':
        return '🇸🇦';
      default:
        return '🌐';
    }
  }
}