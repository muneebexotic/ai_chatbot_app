import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/image_generation_constants.dart';
import '../../utils/app_theme.dart';

class ImageGenerationInput extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? errorText;
  final bool isLoading;
  final VoidCallback? onEnhancePrompt;
  final VoidCallback? onShowSuggestions;
  final Function(String)? onChanged;
  final VoidCallback? onSubmitted;
  final int? maxLength;
  final int maxLines;
  final bool showEnhanceButton;
  final bool showSuggestionsButton;

  const ImageGenerationInput({
    super.key,
    required this.controller,
    this.hintText = ImageGenerationUI.promptHint,
    this.errorText,
    this.isLoading = false,
    this.onEnhancePrompt,
    this.onShowSuggestions,
    this.onChanged,
    this.onSubmitted,
    this.maxLength = ImageGenerationConstants.maxPromptLength,
    this.maxLines = 4,
    this.showEnhanceButton = true,
    this.showSuggestionsButton = true,
  });

  @override
  State<ImageGenerationInput> createState() => _ImageGenerationInputState();
}

class _ImageGenerationInputState extends State<ImageGenerationInput>
    with TickerProviderStateMixin {
  bool _isFocused = false;
  late AnimationController _enhanceController;
  late AnimationController _suggestionsController;
  late Animation<double> _enhanceAnimation;
  late Animation<double> _suggestionsAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _enhanceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _suggestionsController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _enhanceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _enhanceController,
      curve: Curves.easeInOut,
    ));

    _suggestionsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _suggestionsController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _enhanceController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  void _onFocusChanged(bool focused) {
    if (_isFocused != focused) {
      setState(() => _isFocused = focused);
      
      if (focused) {
        _enhanceController.forward();
        _suggestionsController.forward();
      } else {
        _enhanceController.reverse();
        _suggestionsController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main input container
        Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.errorText != null
                  ? AppColors.error
                  : _isFocused
                      ? AppColors.primary
                      : AppColors.getTextTertiary(isDark).withOpacity(0.3),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              // Text input area
              Focus(
                onFocusChange: _onFocusChanged,
                child: TextField(
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  enabled: !widget.isLoading,
                  maxLength: widget.maxLength,
                  maxLines: widget.maxLines,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextPrimary(isDark),
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: AppColors.getTextTertiary(isDark),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                    counterText: '', // Hide character counter
                  ),
                ),
              ),

              // Action buttons row
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _isFocused || widget.controller.text.isNotEmpty ? 56 : 0,
                child: _isFocused || widget.controller.text.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Character count
                            Text(
                              '${widget.controller.text.length}/${widget.maxLength}',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.controller.text.length > (widget.maxLength! * 0.9)
                                    ? AppColors.error
                                    : AppColors.getTextTertiary(isDark),
                              ),
                            ),

                            const Spacer(),

                            // Suggestions button
                            if (widget.showSuggestionsButton && widget.onShowSuggestions != null)
                              ScaleTransition(
                                scale: _suggestionsAnimation,
                                child: _ActionButton(
                                  icon: Icons.lightbulb_outline,
                                  label: 'Ideas',
                                  onPressed: widget.onShowSuggestions,
                                  isLoading: false,
                                ),
                              ),

                            if (widget.showSuggestionsButton && 
                                widget.showEnhanceButton && 
                                widget.onEnhancePrompt != null)
                              const SizedBox(width: 8),

                            // Enhance button
                            if (widget.showEnhanceButton && widget.onEnhancePrompt != null)
                              ScaleTransition(
                                scale: _enhanceAnimation,
                                child: _ActionButton(
                                  icon: Icons.auto_fix_high,
                                  label: 'Enhance',
                                  onPressed: widget.controller.text.trim().isNotEmpty
                                      ? widget.onEnhancePrompt
                                      : null,
                                  isLoading: widget.isLoading,
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // Error text
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Helper text
        if (widget.errorText == null && _isFocused)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              ImageGenerationUI.promptHelperText,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextTertiary(isDark),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: onPressed != null
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.getTextTertiary(isDark).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: onPressed != null
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.getTextTertiary(isDark).withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 14,
                  color: onPressed != null
                      ? AppColors.primary
                      : AppColors.getTextTertiary(isDark),
                ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onPressed != null
                      ? AppColors.primary
                      : AppColors.getTextTertiary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}