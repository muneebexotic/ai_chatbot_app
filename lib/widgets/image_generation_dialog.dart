import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/image_generation_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/themes_provider.dart';
import '../controllers/image_generation_controller.dart';
import '../components/ui/image_generation_input.dart';
import '../components/ui/image_loading_indicator.dart';
import '../constants/image_generation_constants.dart';
import '../models/image_generation_request.dart';
import '../utils/app_theme.dart';
import 'image_prompt_suggestions.dart';

class ImageGenerationDialog extends StatefulWidget {
  const ImageGenerationDialog({super.key});

  @override
  State<ImageGenerationDialog> createState() => _ImageGenerationDialogState();
}

class _ImageGenerationDialogState extends State<ImageGenerationDialog>
    with TickerProviderStateMixin {
  final _promptController = TextEditingController();
  final _negativePromptController = TextEditingController();
  final _seedController = TextEditingController();
  late ImageGenerationController _controller;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  String? _promptError;
  bool _showAdvancedSettings = false;
  double _guidanceScale = 7.5;
  int _steps = 25;

  @override
  void initState() {
    super.initState();
    _controller = ImageGenerationController(context);
    _setupAnimations();
    _loadSettings();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: ImageGenerationConstants.slideUpDuration,
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  void _loadSettings() {
    final provider = Provider.of<ImageGenerationProvider>(context, listen: false);
    _guidanceScale = 7.5; // Default value
    _steps = provider.selectedQuality == ImageQuality.hd ? 50 : 25;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _seedController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final prompt = _promptController.text.trim();
    
    if (prompt.isEmpty) {
      setState(() => _promptError = ImageGenerationErrors.invalidPrompt);
      return false;
    }
    
    if (prompt.length < ImageGenerationConstants.minPromptLength) {
      setState(() => _promptError = ImageGenerationErrors.promptTooShort);
      return false;
    }
    
    if (prompt.length > ImageGenerationConstants.maxPromptLength) {
      setState(() => _promptError = ImageGenerationErrors.promptTooLong);
      return false;
    }

    setState(() => _promptError = null);
    return true;
  }

  Future<void> _generateImage() async {
    if (!_validateInputs()) return;

    final prompt = _promptController.text.trim();
    final negativePrompt = _negativePromptController.text.trim();
    final seed = int.tryParse(_seedController.text.trim());

    try {
      final result = await _controller.generateImage(
        prompt,
        negativePrompt: negativePrompt.isNotEmpty ? negativePrompt : null,
        seed: seed,
        guidanceScale: _guidanceScale,
        steps: _steps,
      );

      if (result != null && mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      // Error handling is done in the controller
    }
  }

  void _enhancePrompt() {
    final currentPrompt = _promptController.text.trim();
    if (currentPrompt.isEmpty) return;

    final enhanced = _controller.enhancePrompt(currentPrompt);
    if (enhanced != currentPrompt) {
      _promptController.text = enhanced;
    }
  }

  void _showPromptSuggestions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ImagePromptSuggestions(),
    ).then((selectedPrompt) {
      if (selectedPrompt != null && selectedPrompt is String) {
        _promptController.text = selectedPrompt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return Consumer<ImageGenerationProvider>(
      builder: (context, imageProvider, child) {
        if (imageProvider.isGenerating) {
          return _buildGeneratingDialog(isDark, imageProvider);
        }

        return SlideTransition(
          position: _slideAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: ImageGenerationConstants.dialogMaxWidth,
                maxHeight: ImageGenerationConstants.dialogMaxHeight,
              ),
              decoration: BoxDecoration(
                color: AppColors.getBackground(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(isDark),
                  Flexible(child: _buildContent(isDark, imageProvider)),
                  _buildFooter(isDark, imageProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneratingDialog(bool isDark, ImageGenerationProvider provider) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ImageLoadingIndicator(
        progress: provider.generationProgress,
        status: provider.generationStatus,
        showCancel: true,
        onCancel: () {
          _controller.cancelGeneration();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ImageGenerationUI.generateImageTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                Text(
                  'Create stunning images with AI',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, ImageGenerationProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main prompt input
          Text(
            ImageGenerationUI.promptLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 12),
          ImageGenerationInput(
            controller: _promptController,
            errorText: _promptError,
            onEnhancePrompt: _enhancePrompt,
            onShowSuggestions: _showPromptSuggestions,
            onChanged: (_) => setState(() => _promptError = null),
          ),

          const SizedBox(height: 24),

          // Generation settings
          _buildGenerationSettings(isDark, provider),

          if (_showAdvancedSettings) ...[
            const SizedBox(height: 24),
            _buildAdvancedSettings(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerationSettings(bool isDark, ImageGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getTextTertiary(isDark).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),

          // Size selector
          _buildSettingRow(
            isDark,
            'Size',
            DropdownButton<ImageSize>(
              value: provider.selectedSize,
              isExpanded: true,
              dropdownColor: AppColors.getSurface(isDark),
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              items: ImageSize.values.map((size) => DropdownMenuItem(
                value: size,
                child: Text(size.getDisplayName()),
              )).toList(),
              onChanged: (size) {
                if (size != null) {
                  provider.updateSettings(size: size);
                }
              },
            ),
          ),

          const SizedBox(height: 12),

          // Quality selector
          _buildSettingRow(
            isDark,
            'Quality',
            DropdownButton<ImageQuality>(
              value: provider.selectedQuality,
              isExpanded: true,
              dropdownColor: AppColors.getSurface(isDark),
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              items: ImageQuality.values.map((quality) => DropdownMenuItem(
                value: quality,
                child: Text(quality.getDisplayName()),
              )).toList(),
              onChanged: (quality) {
                if (quality != null) {
                  provider.updateSettings(quality: quality);
                  setState(() {
                    _steps = quality == ImageQuality.hd ? 50 : 25;
                  });
                }
              },
            ),
          ),

          const SizedBox(height: 12),

          // Style selector
          _buildSettingRow(
            isDark,
            'Style',
            DropdownButton<ImageStyle>(
              value: provider.selectedStyle,
              isExpanded: true,
              dropdownColor: AppColors.getSurface(isDark),
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              items: ImageStyle.values.map((style) => DropdownMenuItem(
                value: style,
                child: Text(style.getDisplayName()),
              )).toList(),
              onChanged: (style) {
                if (style != null) {
                  provider.updateSettings(style: style);
                }
              },
            ),
          ),

          const SizedBox(height: 16),

          // Advanced settings toggle
          TextButton(
            onPressed: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Advanced Settings',
                  style: TextStyle(color: AppColors.primary),
                ),
                Icon(
                  _showAdvancedSettings
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getTextTertiary(isDark).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),

          // Negative prompt
          Text(
            ImageGenerationUI.negativePromptLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _negativePromptController,
            maxLines: 2,
            maxLength: ImageGenerationConstants.maxNegativePromptLength,
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: InputDecoration(
              hintText: ImageGenerationUI.negativePromptHint,
              hintStyle: TextStyle(color: AppColors.getTextTertiary(isDark)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              counterText: '',
            ),
          ),

          const SizedBox(height: 16),

          // Seed input
          _buildSettingRow(
            isDark,
            'Seed (optional)',
            TextField(
              controller: _seedController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              decoration: InputDecoration(
                hintText: ImageGenerationUI.seedHint,
                hintStyle: TextStyle(color: AppColors.getTextTertiary(isDark)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Guidance scale
          Text(
            'Guidance Scale: ${_guidanceScale.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          Slider(
            value: _guidanceScale,
            min: ImageGenerationConstants.minGuidanceScale,
            max: ImageGenerationConstants.maxGuidanceScale,
            divisions: 19,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _guidanceScale = value),
          ),

          const SizedBox(height: 8),

          // Steps
          Text(
            'Steps: $_steps',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          Slider(
            value: _steps.toDouble(),
            min: ImageGenerationConstants.minSteps.toDouble(),
            max: ImageGenerationConstants.maxSteps.toDouble(),
            divisions: 14,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _steps = value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(bool isDark, String label, Widget control) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: control,
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark, ImageGenerationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Usage info
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authProvider.isPremium
                            ? ImageGenerationUI.premiumUsageInfo
                            : ImageGenerationUI.getRemainingUsage(
                                authProvider.paymentService.remainingImages,
                                ImageGenerationConstants.freeImagesPerDay,
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: Text(
                    ImageGenerationUI.cancelButton,
                    style: TextStyle(
                      color: AppColors.getTextSecondary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: provider.isGenerating ? null : _generateImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ImageGenerationUI.generateButton,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}