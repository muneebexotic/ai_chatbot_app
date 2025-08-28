import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? colorScheme.surface,
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: iconColor ?? colorScheme.onSurface,
          size: 20,
        ),
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
      ),
    );
  }
}
