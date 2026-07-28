import 'package:flutter/material.dart';

import 'package:speakwise/l10n/app_localizations.dart';
import '../ui/app_button.dart';
import '../../constants/welcome_screen_constants.dart';

class WelcomeActions extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<Offset> buttonsSlideAnimation;
  final VoidCallback onLoginPressed;
  final VoidCallback onSignUpPressed;

  const WelcomeActions({
    super.key,
    required this.fadeAnimation,
    required this.buttonsSlideAnimation,
    required this.onLoginPressed,
    required this.onSignUpPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: buttonsSlideAnimation,
        child: Column(
          children: [
            // Login Button
            AppButton.primary(
              text: AppLocalizations.of(context).authLogin,
              onPressed: onLoginPressed,
              isFullWidth: true,
            ),

            const SizedBox(height: WelcomeScreenConstants.buttonSpacing),

            // Sign Up Button
            AppButton.secondary(
              text: AppLocalizations.of(context).authSignUp,
              onPressed: onSignUpPressed,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}