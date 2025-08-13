import 'package:flutter/material.dart';
import '../ui/app_text.dart';
import '../ui/social_button.dart';
import '../../constants/welcome_screen_constants.dart';
import '../../utils/app_theme.dart';

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
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: buttonsSlideAnimation,
        child: Column(
          children: [
            const SizedBox(height: WelcomeScreenConstants.socialSectionSpacing),

            // Divider with text
            _buildDivider(),

            const SizedBox(height: WelcomeScreenConstants.dividerSpacing),

            // Google Sign-In Button
            SocialButton.google(
              onPressed: isLoading ? () {} : onGoogleSignIn,
            ),

            if (isLoading) ...[
              const SizedBox(height: 16),
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: WelcomeScreenConstants.dividerHeight,
            color: AppColors.textTertiary.withOpacity(
              WelcomeScreenConstants.dividerOpacity,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: WelcomeScreenConstants.dividerHorizontalSpacing,
          ),
          child: AppText.bodyMedium(
            WelcomeScreenConstants.dividerText,
            color: AppColors.textTertiary,
          ),
        ),
        Expanded(
          child: Container(
            height: WelcomeScreenConstants.dividerHeight,
            color: AppColors.textTertiary.withOpacity(
              WelcomeScreenConstants.dividerOpacity,
            ),
          ),
        ),
      ],
    );
  }
}