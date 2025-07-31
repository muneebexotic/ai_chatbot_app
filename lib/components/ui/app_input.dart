import 'package:ai_chatbot_app/components/ui/app_text.dart';
import 'package:ai_chatbot_app/utils/app_theme.dart';
import 'package:flutter/material.dart';

enum AppInputType { text, email, password, phone, multiline }

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final int? maxLines;
  final TextInputType? keyboardType;
  final AppInputType _type;

  const AppInput._({
    super.key,
    required this.controller,
    required AppInputType type,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.onToggleVisibility,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
  }) : _type = type;

  // Factory constructors for different input types
  const AppInput.text({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
  }) : _type = AppInputType.text,
       obscureText = false,
       onToggleVisibility = null,
       keyboardType = null;

  const AppInput.email({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.validator,
    this.onTap,
    this.readOnly = false,
  }) : _type = AppInputType.email,
       prefixIcon = Icons.email_outlined,
       suffixIcon = null,
       obscureText = false,
       onToggleVisibility = null,
       maxLines = 1,
       keyboardType = TextInputType.emailAddress;

  const AppInput.password({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    required this.obscureText,
    required this.onToggleVisibility,
    this.validator,
    this.onTap,
    this.readOnly = false,
  }) : _type = AppInputType.password,
       prefixIcon = Icons.lock_outline,
       suffixIcon = null,
       maxLines = 1,
       keyboardType = null;

  const AppInput.phone({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.validator,
    this.onTap,
    this.readOnly = false,
  }) : _type = AppInputType.phone,
       prefixIcon = Icons.phone_outlined,
       suffixIcon = null,
       obscureText = false,
       onToggleVisibility = null,
       maxLines = 1,
       keyboardType = TextInputType.phone;

  const AppInput.multiline({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.maxLines = 3,
    this.validator,
    this.onTap,
    this.readOnly = false,
  }) : _type = AppInputType.multiline,
       prefixIcon = null,
       suffixIcon = null,
       obscureText = false,
       onToggleVisibility = null,
       keyboardType = TextInputType.multiline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          AppText.bodyMedium(label!, color: AppColors.textSecondary),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          onTap: onTap,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 16),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.textSecondary)
                : null,
            suffixIcon: _buildSuffixIcon(),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.surfaceVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            errorStyle: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (_type == AppInputType.password) {
      return IconButton(
        icon: Icon(
          obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppColors.textSecondary,
        ),
        onPressed: onToggleVisibility,
      );
    }
    return suffixIcon;
  }
}
