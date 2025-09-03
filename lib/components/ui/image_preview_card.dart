import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/generated_image.dart';
import '../../constants/image_generation_constants.dart';
import '../../providers/themes_provider.dart';
import '../../utils/app_theme.dart';
import '../ui/app_text.dart';

class ImagePreviewCard extends StatefulWidget {
  final GeneratedImage image;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final bool showActions;
  final bool isSelected;
  final double? width;
  final double? height;

  const ImagePreviewCard({
    super.key,
    required this.image,
    this.onTap,
    this.onFavorite,
    this.onShare,
    this.onSave,
    this.onDelete,
    this.showActions = true,
    this.isSelected = false,
    this.width,
    this.height,
  });

  @override
  State<ImagePreviewCard> createState() => _ImagePreviewCardState();
}

class _ImagePreviewCardState extends State<ImagePreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadImage();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: ImageGenerationConstants.fadeInDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  void _loadImage() {
    // Simulate image loading
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = !widget.image.isValid();
        });
        _animationController.forward();
      }
    });
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleFavorite() {
    HapticFeedback.lightImpact();
    widget.onFavorite?.call();
  }

  void _handleShare() {
    HapticFeedback.lightImpact();
    widget.onShare?.call();
  }

  void _handleSave() {
    HapticFeedback.lightImpact();
    widget.onSave?.call();
  }

  void _handleDelete() {
    HapticFeedback.lightImpact();
    widget.onDelete?.call();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDark;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildCard(isDark),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCard(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.width ?? ImageGenerationConstants.previewImageWidth,
      height: widget.height ?? ImageGenerationConstants.previewImageHeight,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isSelected
              ? AppColors.primary
              : (_isHovered
                    ? AppColors.primary.withOpacity(0.3)
                    : AppColors.getTextTertiary(isDark).withOpacity(0.1)),
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: _isHovered ? 20 : 8,
            spreadRadius: _isHovered ? 2 : 0,
            offset: Offset(0, _isHovered ? 8 : 4),
          ),
          if (widget.isSelected)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageContent(isDark),
            if (widget.showActions) _buildActionOverlay(isDark),
            if (widget.image.isFavorite) _buildFavoriteIndicator(isDark),
            _buildInfoOverlay(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(bool isDark) {
    if (_isLoading) {
      return _buildLoadingPlaceholder(isDark);
    }

    if (_hasError || !widget.image.hasLocalData) {
      return _buildErrorPlaceholder(isDark);
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Image.memory(
        widget.image.imageData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder(isDark);
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.getSurfaceVariant(isDark),
            AppColors.getSurface(isDark),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            AppText.bodySmall(
              'Loading...',
              color: AppColors.getTextSecondary(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.getSurfaceVariant(isDark),
            AppColors.getSurface(isDark),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 40,
              color: AppColors.getTextTertiary(isDark),
            ),
            const SizedBox(height: 8),
            AppText.bodySmall(
              'Image unavailable',
              color: AppColors.getTextTertiary(isDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOverlay(bool isDark) {
    return Positioned.fill(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isHovered ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              stops: const [0.5, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: widget.image.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      onPressed: _handleFavorite,
                      color: widget.image.isFavorite
                          ? Colors.red
                          : Colors.white,
                      tooltip: widget.image.isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                    ),
                    _buildActionButton(
                      icon: Icons.share_rounded,
                      onPressed: _handleShare,
                      color: Colors.white,
                      tooltip: 'Share image',
                    ),
                    _buildActionButton(
                      icon: Icons.download_rounded,
                      onPressed: _handleSave,
                      color: Colors.white,
                      tooltip: 'Save to gallery',
                    ),
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      onPressed: _handleDelete,
                      color: Colors.red,
                      tooltip: 'Delete image',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.5),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteIndicator(bool isDark) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildInfoOverlay(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isHovered ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText.bodySmall(
                widget.image.prompt.length > 60
                    ? '${widget.image.prompt.substring(0, 60)}...'
                    : widget.image.prompt,
                color: Colors.white,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                fontWeight: FontWeight.w500,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AppText.labelSmall(
                      widget.image.getDimensionsString(),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AppText.labelSmall(
                      widget.image.style.getDisplayName(),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
