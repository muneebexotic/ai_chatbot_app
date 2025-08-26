import 'package:flutter/material.dart';
import '../ui/app_logo.dart';
import '../ui/app_text.dart';
import '../../constants/welcome_screen_constants.dart';

class WelcomeHeader extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final Animation<Offset> titleSlideAnimation;
  final Animation<double> subtitleFadeAnimation;

  const WelcomeHeader({
    super.key,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.titleSlideAnimation,
    required this.subtitleFadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Logo with animation
        FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: const AppLogo(
              size: AppLogoSize.large,
              showGlow: true,
            ),
          ),
        ),

        const SizedBox(height: WelcomeScreenConstants.logoTitleSpacing),

        // Welcome Title - now theme-aware
        FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: titleSlideAnimation,
            child: AppText.displayMedium(
              WelcomeScreenConstants.welcomeTitle,
              color: colorScheme.onBackground, // Use theme-aware color
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: WelcomeScreenConstants.titleSubtitleSpacing),

        // Subtitle - now theme-aware
        FadeTransition(
          opacity: subtitleFadeAnimation,
          child: AppText.bodyLarge(
            WelcomeScreenConstants.welcomeSubtitle,
            color: colorScheme.onBackground.withOpacity(0.7), // Theme-aware secondary color
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}