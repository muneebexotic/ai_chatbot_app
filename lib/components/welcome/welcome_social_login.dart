import 'package:flutter/material.dart';
import '../ui/app_text.dart';
import '../ui/social_button.dart';
import '../../constants/welcome_screen_constants.dart';

class WelcomeSocialLogin extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<Offset> buttonsSlideAnimation;
  final VoidCallback onGoogleSignIn;
  final bool isLoading;

  const WelcomeSocialLogin({
    super.key,
    required this.fadeAnimation,
    required this.buttonsSlideAnimation,
    required this.onGoogleSignIn,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: buttonsSlideAnimation,
        child: Column(
          children: [
            const SizedBox(height: WelcomeScreenConstants.socialSectionSpacing),

            _buildDivider(context),

            const SizedBox(height: WelcomeScreenConstants.dividerSpacing),

            SocialButton.google(
              onPressed: isLoading ? () {} : onGoogleSignIn,
            ),

            if (isLoading) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: WelcomeScreenConstants.dividerHeight,
            color: colorScheme.outline.withOpacity(
              WelcomeScreenConstants.dividerOpacity,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WelcomeScreenConstants.dividerHorizontalSpacing,
          ),
          child: AppText.bodyMedium(
            WelcomeScreenConstants.dividerText,
            color: colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
        Expanded(
          child: Container(
            height: WelcomeScreenConstants.dividerHeight,
            color: colorScheme.outline.withOpacity(
              WelcomeScreenConstants.dividerOpacity,
            ),
          ),
        ),
      ],
    );
  }
}