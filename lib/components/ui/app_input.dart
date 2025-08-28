import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/app_text.dart';

// Keep old enum for backward compatibility
enum AppInputType { text, email, password, phone, multiline }

class AppInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? hintText; // Added for backward compatibility
  final String? errorText;
  final String? helperText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onToggleVisibility; // Added for backward compatibility
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final double? borderRadius;
  final AppInputType? _type; // Added for backward compatibility

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.hintText, // Added for backward compatibility
    this.errorText,
    this.helperText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onToggleVisibility, // Added for backward compatibility
    this.validator,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.focusNode,
    this.contentPadding,
    this.borderRadius,
  }) : _type = null;

  // Old-style constructor for backward compatibility
  const AppInput._withType({
    super.key,
    required AppInputType type,
    required TextEditingController this.controller,
    this.label,
    this.hint,
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
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.focusNode,
    this.contentPadding,
    this.borderRadius,
  }) : _type = type;

  // Email input factory
  factory AppInput.email({
    String? label,
    String? hint,
    String? hintText,
    String? errorText,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    VoidCallback? onTap,
    bool readOnly = false,
    Key? key,
  }) =>
      AppInput._withType(
        key: key,
        type: AppInputType.email,
        controller: controller!,
        label: label,
        hint: hint,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: const Icon(Icons.email_outlined),
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        textInputAction: TextInputAction.next,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        validator: validator,
        focusNode: focusNode,
        onTap: onTap,
        readOnly: readOnly,
      );

  // Password input factory
  factory AppInput.password({
    String? label,
    String? hint,
    String? hintText,
    String? errorText,
    TextEditingController? controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    Widget? suffixIcon,
    VoidCallback? onTap,
    bool readOnly = false,
    Key? key,
  }) =>
      AppInput._withType(
        key: key,
        type: AppInputType.password,
        controller: controller!,
        label: label,
        hint: hint,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: const Icon(Icons.lock_outline),
        obscureText: obscureText,
        onToggleVisibility: onToggleVisibility,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        validator: validator,
        focusNode: focusNode,
        suffixIcon: suffixIcon,
        onTap: onTap,
        readOnly: readOnly,
      );

  // Text input factory for backward compatibility
  factory AppInput.text({
    String? label,
    String? hint,
    String? hintText,
    String? errorText,
    TextEditingController? controller,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
    int? maxLines = 1,
    ValueChanged<String>? onChanged,
    Key? key,
  }) =>
      AppInput._withType(
        key: key,
        type: AppInputType.text,
        controller: controller!,
        label: label,
        hint: hint,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        maxLines: maxLines,
        onChanged: onChanged,
      );

  // Phone input factory for backward compatibility
  factory AppInput.phone({
    String? label,
    String? hint,
    String? hintText,
    String? errorText,
    TextEditingController? controller,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    Key? key,
  }) =>
      AppInput._withType(
        key: key,
        type: AppInputType.phone,
        controller: controller!,
        label: label,
        hint: hint,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: const Icon(Icons.phone_outlined),
        keyboardType: TextInputType.phone,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        onChanged: onChanged,
      );

  // Search input factory
  factory AppInput.search({
    String? hint,
    String? hintText,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FocusNode? focusNode,
    Key? key,
  }) =>
      AppInput(
        key: key,
        hint: hint,
        hintText: hintText,
        controller: controller,
        prefixIcon: const Icon(Icons.search),
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        focusNode: focusNode,
      );

  // Multiline input factory
  factory AppInput.multiline({
    String? label,
    String? hint,
    String? hintText,
    String? errorText,
    TextEditingController? controller,
    int maxLines = 5,
    int minLines = 3,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    VoidCallback? onTap,
    bool readOnly = false,
    Key? key,
  }) =>
      AppInput._withType(
        key: key,
        type: AppInputType.multiline,
        controller: controller!,
        label: label,
        hint: hint,
        hintText: hintText,
        errorText: errorText,
        maxLines: maxLines,
        minLines: minLines,
        textCapitalization: TextCapitalization.sentences,
        onChanged: onChanged,
        validator: validator,
        focusNode: focusNode,
        onTap: onTap,
        readOnly: readOnly,
      );

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Use hintText for backward compatibility if hint is null
    final effectiveHint = widget.hint ?? widget.hintText;
    
    // Theme-aware colors
    final backgroundColor = colorScheme.surface;
    final borderColor = _getBorderColor(context);
    final textColor = colorScheme.onSurface;
    final hintColor = colorScheme.onSurface.withOpacity(0.6);
    final labelColor = colorScheme.onSurface.withOpacity(0.8);
    
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final effectiveBorderRadius = widget.borderRadius ?? 16.0;
    final effectiveContentPadding = widget.contentPadding ?? 
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: AppText.labelMedium(
              widget.label!,
              color: hasError ? colorScheme.error : labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        // Input Field
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(effectiveBorderRadius),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: _isFocused && !hasError
                ? [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            onEditingComplete: widget.onEditingComplete,
            validator: widget.validator,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              hintText: effectiveHint,
              hintStyle: TextStyle(
                color: hintColor,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Poppins',
              ),
              prefixIcon: widget.prefixIcon != null
                  ? IconTheme(
                      data: IconThemeData(color: hintColor),
                      child: widget.prefixIcon!,
                    )
                  : null,
              suffixIcon: _buildSuffixIcon(),
              contentPadding: effectiveContentPadding,
              border: InputBorder.none,
              counterText: '', // Hide counter
            ),
          ),
        ),

        // Error Text
        if (hasError) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText.bodySmall(
                    widget.errorText!,
                    color: colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Helper Text
        if (widget.helperText != null && !hasError) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: AppText.bodySmall(
              widget.helperText!,
              color: hintColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget._type == AppInputType.password || widget.onToggleVisibility != null) {
      return IconButton(
        icon: Icon(
          widget.obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        onPressed: widget.onToggleVisibility,
      );
    }
    return widget.suffixIcon != null
        ? IconTheme(
            data: IconThemeData(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            child: widget.suffixIcon!,
          )
        : null;
  }

  Color _getBorderColor(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (widget.errorText != null && widget.errorText!.isNotEmpty) {
      return colorScheme.error;
    }
    
    if (_isFocused) {
      return theme.primaryColor;
    }
    
    if (!widget.enabled) {
      return colorScheme.outline.withOpacity(0.3);
    }
    
    return colorScheme.outline.withOpacity(0.5);
  }
}