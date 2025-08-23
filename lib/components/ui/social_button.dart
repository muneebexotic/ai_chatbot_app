import 'package:ai_chatbot_app/utils/app_theme.dart';
import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String _iconPath;

  const SocialButton.google({super.key, required this.onPressed})
    : _iconPath = 'assets/google_logo.png';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceVariant, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: Image.asset(_iconPath, width: 28, height: 28)),
      ),
    );
  }
}
