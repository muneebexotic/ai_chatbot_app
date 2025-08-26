import 'package:flutter/material.dart';
import '../ui/app_text.dart';

enum AppButtonStyle {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
}

// Keep the old enum for backward compatibility
enum AppButtonSize { small, medium, large }
enum AppButtonType { primary, secondary, outline, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool isLoading;
  final bool isExpanded;
  final bool isFullWidth; // Added for backward compatibility
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final double? borderRadius;
  final AppButtonSize size; // Added for backward compatibility

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.isLoading = false,
    this.isExpanded = false,
    this.isFullWidth = false, // Added for backward compatibility
    this.icon,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.size = AppButtonSize.medium, // Added for backward compatibility
  });

  // Primary button factory
  factory AppButton.primary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isExpanded = false,
    bool isFullWidth = false, // Added for backward compatibility
    AppButtonSize size = AppButtonSize.medium, // Added for backward compatibility
    IconData? icon,
    double? width,
    double? height,
    Key? key,
  }) =>
      AppButton(
        key: key,
        text: text,
        onPressed: onPressed,
        style: AppButtonStyle.primary,
        isLoading: isLoading,
        isExpanded: isExpanded || isFullWidth,
        isFullWidth: isFullWidth,
        icon: icon,
        width: width,
        height: height,
        size: size,
      );

  // Secondary button factory
  factory AppButton.secondary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isExpanded = false,
    bool isFullWidth = false, // Added for backward compatibility
    AppButtonSize size = AppButtonSize.medium, // Added for backward compatibility
    IconData? icon,
    double? width,
    double? height,
    Key? key,
  }) =>
      AppButton(
        key: key,
        text: text,
        onPressed: onPressed,
        style: AppButtonStyle.secondary,
        isLoading: isLoading,
        isExpanded: isExpanded || isFullWidth,
        isFullWidth: isFullWidth,
        icon: icon,
        width: width,
        height: height,
        size: size,
      );

  // Outline button factory
  factory AppButton.outline({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isExpanded = false,
    bool isFullWidth = false, // Added for backward compatibility
    AppButtonSize size = AppButtonSize.medium, // Added for backward compatibility
    IconData? icon,
    double? width,
    double? height,
    Key? key,
  }) =>
      AppButton(
        key: key,
        text: text,
        onPressed: onPressed,
        style: AppButtonStyle.outline,
        isLoading: isLoading,
        isExpanded: isExpanded || isFullWidth,
        isFullWidth: isFullWidth,
        icon: icon,
        width: width,
        height: height,
        size: size,
      );

  // Ghost button factory
  factory AppButton.ghost({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isExpanded = false,
    bool isFullWidth = false, // Added for backward compatibility
    AppButtonSize size = AppButtonSize.medium, // Added for backward compatibility
    IconData? icon,
    double? width,
    double? height,
    Key? key,
  }) =>
      AppButton(
        key: key,
        text: text,
        onPressed: onPressed,
        style: AppButtonStyle.ghost,
        isLoading: isLoading,
        isExpanded: isExpanded || isFullWidth,
        isFullWidth: isFullWidth,
        icon: icon,
        width: width,
        height: height,
        size: size,
      );

  // Destructive button factory
  factory AppButton.destructive({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isExpanded = false,
    bool isFullWidth = false, // Added for backward compatibility
    AppButtonSize size = AppButtonSize.medium, // Added for backward compatibility
    IconData? icon,
    double? width,
    double? height,
    Key? key,
  }) =>
      AppButton(
        key: key,
        text: text,
        onPressed: onPressed,
        style: AppButtonStyle.destructive,
        isLoading: isLoading,
        isExpanded: isExpanded || isFullWidth,
        isFullWidth: isFullWidth,
        icon: icon,
        width: width,
        height: height,
        size: size,
      );

  // Text button factory (for backward compatibility)
  factory AppButton.text({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isExpanded = false,
    bool isFullWidth = false,
    AppButtonSize size = AppButtonSize.medium,
    IconData? icon,
    double? width,
    double? height,
    Key? key,
  }) =>
      AppButton(
        key: key,
        text: text,
        onPressed: onPressed,
        style: AppButtonStyle.ghost,
        isLoading: isLoading,
        isExpanded: isExpanded || isFullWidth,
        isFullWidth: isFullWidth,
        icon: icon,
        width: width,
        height: height,
        size: size,
      );

  // Size-based height calculation for backward compatibility
  double get _height {
    if (height != null) return height!;
    
    switch (size) {
      case AppButtonSize.small:
        return 40;
      case AppButtonSize.medium:
        return 52;
      case AppButtonSize.large:
        return 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Get button style properties based on theme
    final buttonStyle = _getButtonStyle(context);
    
    final effectiveWidth = (isExpanded || isFullWidth) ? double.infinity : width;
    final effectiveHeight = _height;
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    final effectiveBorderRadius = borderRadius ?? 16.0;

    Widget buttonContent = Row(
      mainAxisSize: (isExpanded || isFullWidth) ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(buttonStyle.textColor),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: buttonStyle.textColor),
          const SizedBox(width: 12),
        ],
        AppText.labelLarge(
          text,
          color: buttonStyle.textColor,
          fontWeight: FontWeight.w600,
        ),
      ],
    );

    return SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonStyle.backgroundColor,
          foregroundColor: buttonStyle.textColor,
          disabledBackgroundColor: buttonStyle.disabledBackgroundColor,
          disabledForegroundColor: buttonStyle.disabledTextColor,
          elevation: buttonStyle.elevation,
          shadowColor: buttonStyle.shadowColor,
          side: buttonStyle.borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(effectiveBorderRadius),
          ),
          padding: effectivePadding,
        ),
        child: buttonContent,
      ),
    );
  }

  _ButtonStyleData _getButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = theme.primaryColor;
    
    switch (style) {
      case AppButtonStyle.primary:
        return _ButtonStyleData(
          backgroundColor: primaryColor,
          textColor: Colors.white,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          disabledTextColor: colorScheme.onSurface.withOpacity(0.38),
          elevation: 0,
          shadowColor: primaryColor.withOpacity(0.3),
        );

      case AppButtonStyle.secondary:
        return _ButtonStyleData(
          backgroundColor: colorScheme.surface,
          textColor: colorScheme.onSurface,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          disabledTextColor: colorScheme.onSurface.withOpacity(0.38),
          elevation: 0,
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        );

      case AppButtonStyle.outline:
        return _ButtonStyleData(
          backgroundColor: Colors.transparent,
          textColor: primaryColor,
          disabledBackgroundColor: Colors.transparent,
          disabledTextColor: colorScheme.onSurface.withOpacity(0.38),
          elevation: 0,
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        );

      case AppButtonStyle.ghost:
        return _ButtonStyleData(
          backgroundColor: Colors.transparent,
          textColor: primaryColor,
          disabledBackgroundColor: Colors.transparent,
          disabledTextColor: colorScheme.onSurface.withOpacity(0.38),
          elevation: 0,
        );

      case AppButtonStyle.destructive:
        return _ButtonStyleData(
          backgroundColor: colorScheme.error,
          textColor: Colors.white,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          disabledTextColor: colorScheme.onSurface.withOpacity(0.38),
          elevation: 0,
          shadowColor: colorScheme.error.withOpacity(0.3),
        );
    }
  }
}

class _ButtonStyleData {
  final Color backgroundColor;
  final Color textColor;
  final Color disabledBackgroundColor;
  final Color disabledTextColor;
  final double elevation;
  final Color? shadowColor;
  final BorderSide? borderSide;

  const _ButtonStyleData({
    required this.backgroundColor,
    required this.textColor,
    required this.disabledBackgroundColor,
    required this.disabledTextColor,
    required this.elevation,
    this.shadowColor,
    this.borderSide,
  });
}