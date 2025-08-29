import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/generated_image.dart';
import '../providers/image_generation_provider.dart';
import '../providers/themes_provider.dart';
import '../controllers/image_generation_controller.dart';
import '../utils/app_theme.dart';
import '../components/ui/app_text.dart';
import '../constants/image_generation_constants.dart';

class GeneratedImageViewer extends StatefulWidget {
  final GeneratedImage image;

  const GeneratedImageViewer({
    super.key,
    required this.image,
  });

  @override
  State<GeneratedImageViewer> createState() => _GeneratedImageViewerState();
}

class _GeneratedImageViewerState extends State<GeneratedImageViewer>
    with TickerProviderStateMixin {
  late ImageGenerationController _controller;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _showDetails = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = ImageGenerationController(context);
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _toggleDetails() {
    setState(() => _showDetails = !_showDetails);
    if (_showDetails) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
    
    HapticFeedback.lightImpact();
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    
    try {
      await _controller.saveImageToGallery(widget.image);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isLoading = true);
    
    try {
      await _controller.shareImage(widget.image);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCopy() async {
    setState(() => _isLoading = true);
    
    try {
      await _controller.copyImageToClipboard(widget.image);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFavorite() async {
    HapticFeedback.lightImpact();
    await _controller.toggleFavorite(widget.image);
  }

  Future<void> _handleDelete() async {
    final deleted = await _controller.deleteImage(widget.image);
    if (deleted && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleRegenerate() async {
    Navigator.of(context).pop();
    await _controller.regenerateLastImage();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDark;

        return Scaffold(
          backgroundColor: AppColors.getBackground(isDark),
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(isDark),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                // Background gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        AppColors.getBackground(isDark),
                        AppColors.getSurface(isDark).withOpacity(0.8),
                        AppColors.getBackground(isDark),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
                
                // Main content
                Column(
                  children: [
                    Expanded(child: _buildImageDisplay(isDark)),
                    _buildActionBar(isDark),
                  ],
                ),

                // Details overlay
                if (_showDetails) _buildDetailsOverlay(isDark),
                
                // Loading overlay
                if (_isLoading) _buildLoadingOverlay(isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.getBackground(isDark).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.getTextPrimary(isDark),
            size: 20,
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.getBackground(isDark).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Consumer<ImageGenerationProvider>(
            builder: (context, provider, child) {
              final currentImage = provider.generatedImages.firstWhere(
                (img) => img.id == widget.image.id,
                orElse: () => widget.image,
              );
              
              return IconButton(
                onPressed: _handleFavorite,
                icon: Icon(
                  currentImage.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: currentImage.isFavorite ? Colors.red : AppColors.getTextPrimary(isDark),
                  size: 20,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageDisplay(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Hero(
          tag: 'image_${widget.image.id}',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: widget.image.hasLocalData
                    ? Image.memory(
                        widget.image.imageData,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildErrorWidget(isDark),
                      )
                    : widget.image.hasCloudUrl
                        ? Image.network(
                            widget.image.imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _buildLoadingWidget(isDark, loadingProgress);
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _buildErrorWidget(isDark),
                          )
                        : _buildErrorWidget(isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget(bool isDark, ImageChunkEvent? loadingProgress) {
    final progress = loadingProgress != null
        ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
        : 0.0;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          AppText.bodyMedium(
            'Loading image...',
            color: AppColors.getTextSecondary(isDark),
          ),
          if (progress > 0)
            AppText.bodySmall(
              '${(progress * 100).toInt()}%',
              color: AppColors.getTextTertiary(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          AppText.bodyMedium(
            'Failed to load image',
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          AppText.bodySmall(
            'The image may have been corrupted or deleted',
            color: AppColors.getTextTertiary(isDark),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prompt preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    AppText.bodySmall(
                      'Prompt',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleDetails,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppText.bodySmall(
                            'Details',
                            color: AppColors.primary,
                          ),
                          Icon(
                            _showDetails ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppText.bodySmall(
                  widget.image.prompt.length > 80
                      ? '${widget.image.prompt.substring(0, 80)}...'
                      : widget.image.prompt,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.download_outlined,
                  label: 'Save',
                  onTap: _handleSave,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: _handleShare,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.copy_outlined,
                  label: 'Copy',
                  onTap: _handleCopy,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Regenerate',
                  onTap: _handleRegenerate,
                  isDark: isDark,
                  isPrimary: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Delete button
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Delete Image',
              onTap: _handleDelete,
              isDark: isDark,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? AppColors.error
        : isPrimary
            ? AppColors.primary
            : AppColors.getTextSecondary(isDark);

    final backgroundColor = isDestructive
        ? AppColors.error.withOpacity(0.1)
        : isPrimary
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.getTextTertiary(isDark).withOpacity(0.1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              AppText.bodySmall(
                label,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsOverlay(bool isDark) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleDetails,
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: SlideTransition(
            position: _slideAnimation,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppText.bodyLarge(
                          'Image Details',
                          color: AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _toggleDetails,
                          icon: Icon(
                            Icons.close,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildDetailRow('Size', widget.image.size.getDisplayName(), isDark),
                    _buildDetailRow('Quality', widget.image.quality.getDisplayName(), isDark),
                    _buildDetailRow('Style', widget.image.style.getDisplayName(), isDark),
                    _buildDetailRow('Provider', widget.image.provider.getDisplayName(), isDark),
                    _buildDetailRow('Created', _formatDate(widget.image.createdAt), isDark),
                    
                    if (widget.image.seed != null)
                      _buildDetailRow('Seed', widget.image.seed.toString(), isDark),
                    
                    if (widget.image.guidanceScale != null)
                      _buildDetailRow('Guidance Scale', widget.image.guidanceScale!.toStringAsFixed(1), isDark),
                    
                    if (widget.image.steps != null)
                      _buildDetailRow('Steps', widget.image.steps.toString(), isDark),
                    
                    if (widget.image.negativePrompt != null && widget.image.negativePrompt!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      AppText.bodyMedium(
                        'Negative Prompt',
                        color: AppColors.getTextPrimary(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.getBackground(isDark),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                          ),
                        ),
                        child: AppText.bodySmall(
                          widget.image.negativePrompt!,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    AppText.bodyMedium(
                      'Full Prompt',
                      color: AppColors.getTextPrimary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getBackground(isDark),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                        ),
                      ),
                      child: AppText.bodySmall(
                        widget.image.prompt,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: AppText.bodySmall(
              label,
              color: AppColors.getTextTertiary(isDark),
            ),
          ),
          Expanded(
            child: AppText.bodySmall(
              value,
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Positioned.fill(
      child: Container(
        color: AppColors.getBackground(isDark).withOpacity(0.8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                AppText.bodyMedium(
                  'Processing...',
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}