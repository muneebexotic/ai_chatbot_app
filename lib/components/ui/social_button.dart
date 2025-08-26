// social_button.dart - Theme-aware version
import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String _iconPath;

  const SocialButton.google({super.key, required this.onPressed})
    : _iconPath = 'assets/google_logo.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.3), 
            width: 1
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(_iconPath, width: 28, height: 28)
        ),
      ),
    );
  }
}