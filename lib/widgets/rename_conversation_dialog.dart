import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../providers/themes_provider.dart';
import '../components/ui/app_text.dart';

class RenameConversationDialog extends StatefulWidget {
  final String currentTitle;

  const RenameConversationDialog({
    super.key,
    required this.currentTitle,
  });

  @override
  State<RenameConversationDialog> createState() => _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<RenameConversationDialog> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
    _controller.addListener(() {
      final isValid = _controller.text.trim().isNotEmpty;
      if (isValid != _isValid) {
        setState(() {
          _isValid = isValid;
        });
      }
    });

    // Auto-focus and select all text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleRename() {
    final trimmedText = _controller.text.trim();
    if (trimmedText.isNotEmpty) {
      Navigator.pop(context, trimmedText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDark;
        
        return AlertDialog(
          backgroundColor: AppColors.getSurface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText.titleLarge(
                  'Rename Conversation',
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.bodyMedium(
                'Enter a new name for this conversation',
                color: AppColors.getTextSecondary(isDark),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceVariant(isDark).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isValid 
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter conversation title',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextTertiary(isDark),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: AppColors.getTextTertiary(isDark),
                              size: 18,
                            ),
                            onPressed: () => _controller.clear(),
                            tooltip: 'Clear text',
                          )
                        : null,
                  ),
                  maxLength: 100,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRename(),
                ),
              ),
              if (!_isValid) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    AppText.bodySmall(
                      'Please enter a valid conversation title',
                      color: AppColors.error,
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText.bodyMedium(
                'Cancel',
                color: AppColors.getTextSecondary(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
            ElevatedButton(
              onPressed: _isValid ? _handleRename : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isValid 
                    ? AppColors.primary 
                    : AppColors.getTextTertiary(isDark).withOpacity(0.3),
                disabledBackgroundColor: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: AppText.bodyMedium(
                'Rename',
                color: _isValid ? Colors.white : AppColors.getTextTertiary(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}