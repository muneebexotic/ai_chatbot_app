import 'package:flutter/material.dart';
import '../ui/app_logo.dart';
import '../ui/app_text.dart';
import '../../constants/welcome_screen_constants.dart';
import '../../utils/app_theme.dart';

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

        // Welcome Title
        FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: titleSlideAnimation,
            child: const AppText.displayMedium(
              WelcomeScreenConstants.welcomeTitle,
              color: Colors.white,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: WelcomeScreenConstants.titleSubtitleSpacing),

        // Subtitle
        FadeTransition(
          opacity: subtitleFadeAnimation,
          child: const AppText.bodyLarge(
            WelcomeScreenConstants.welcomeSubtitle,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}