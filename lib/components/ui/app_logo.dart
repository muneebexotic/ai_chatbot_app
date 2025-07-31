import 'package:ai_chatbot_app/utils/app_theme.dart';
import 'package:flutter/material.dart';

enum AppLogoSize { small, medium, large, extraLarge }

class AppLogo extends StatelessWidget {
  final AppLogoSize size;
  final bool showGlow;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = AppLogoSize.medium,
    this.showGlow = false,
    this.color,
  });

  double get _logoSize {
    switch (size) {
      case AppLogoSize.small:
        return 32;
      case AppLogoSize.medium:
        return 64;
      case AppLogoSize.large:
        return 120;
      case AppLogoSize.extraLarge:
        return 180;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final responsiveSize = screenWidth * 0.25; // Responsive sizing
    final finalSize = _logoSize > responsiveSize ? responsiveSize : _logoSize;

    Widget logo = Image.asset(
      'assets/logo.png',
      width: finalSize,
      height: finalSize,
      fit: BoxFit.contain,
      color: color,
    );

    if (showGlow) {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: logo,
      );
    }

    return logo;
  }
}
