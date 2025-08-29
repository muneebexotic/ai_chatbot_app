import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/image_generation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/image_generation_request.dart';
import '../models/generated_image.dart';
import '../constants/image_generation_constants.dart';
import '../widgets/image_generation_dialog.dart';
import '../widgets/generated_image_viewer.dart';
import '../screens/subscription_screen.dart';

class ImageGenerationController {
  final BuildContext context;
  
  ImageGenerationController(this.context);

  /// Show image generation dialog
  Future<void> showGenerationDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check usage limits
    final canGenerate = await authProvider.canUploadImage(); // Using image quota
    if (!canGenerate) {
      _showUsageLimitDialog();
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ImageGenerationDialog(),
    );
  }

  /// Generate image with prompt
  Future<GeneratedImage?> generateImage(String prompt, {
    String? negativePrompt,
    int? seed,
    double? guidanceScale,
    int? steps,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);

    // Validate usage limits
    final canGenerate = await authProvider.canUploadImage();
    if (!canGenerate) {
      _showUsageLimitDialog();
      return null;
    }

    try {
      // Increment usage counter
      await authProvider.incrementImageUsage();

      // Generate the image
      final result = await imageProvider.generateImage(
        prompt,
        negativePrompt: negativePrompt,
        seed: seed,
        guidanceScale: guidanceScale,
        steps: steps,
      );

      if (result != null) {
        // Show success message
        _showSnackBar(
          ImageGenerationMessages.generationCompleted,
          isSuccess: true,
        );
        
        // Optionally show the generated image
        await showGeneratedImage(result);
      } else {
        _showSnackBar(
          imageProvider.lastError ?? ImageGenerationErrors.unknownError,
          isSuccess: false,
        );
      }

      return result;
    } catch (e) {
      debugPrint('❌ Image generation error: $e');
      _showSnackBar(
        ImageGenerationErrors.unknownError,
        isSuccess: false,
      );
      return null;
    }
  }

  /// Show generated image in viewer
  Future<void> showGeneratedImage(GeneratedImage image) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GeneratedImageViewer(image: image),
        fullscreenDialog: true,
      ),
    );
  }

  /// Regenerate last image
  Future<void> regenerateLastImage() async {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    if (imageProvider.currentRequest == null) {
      _showSnackBar('No previous image to regenerate', isSuccess: false);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canGenerate = await authProvider.canUploadImage();
    
    if (!canGenerate) {
      _showUsageLimitDialog();
      return;
    }

    try {
      await authProvider.incrementImageUsage();
      
      final result = await imageProvider.regenerateImage();
      if (result != null) {
        _showSnackBar(
          'Image regenerated successfully!',
          isSuccess: true,
        );
        await showGeneratedImage(result);
      } else {
        _showSnackBar(
          imageProvider.lastError ?? 'Failed to regenerate image',
          isSuccess: false,
        );
      }
    } catch (e) {
      debugPrint('❌ Regeneration error: $e');
      _showSnackBar('Failed to regenerate image', isSuccess: false);
    }
  }

  /// Save image to gallery
  Future<void> saveImageToGallery(GeneratedImage image) async {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    try {
      final success = await imageProvider.saveImageToGallery(image);
      
      _showSnackBar(
        success ? ImageGenerationMessages.imageSaved : ImageGenerationErrors.storageError,
        isSuccess: success,
      );
    } catch (e) {
      debugPrint('❌ Save error: $e');
      _showSnackBar(ImageGenerationErrors.storageError, isSuccess: false);
    }
  }

  /// Share generated image
  Future<void> shareImage(GeneratedImage image) async {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    try {
      final success = await imageProvider.shareImage(image);
      
      if (success) {
        _showSnackBar(ImageGenerationMessages.imageShared, isSuccess: true);
      }
    } catch (e) {
      debugPrint('❌ Share error: $e');
      _showSnackBar('Failed to share image', isSuccess: false);
    }
  }

  /// Copy image to clipboard
  Future<void> copyImageToClipboard(GeneratedImage image) async {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    try {
      final success = await imageProvider.copyImageToClipboard(image);
      
      _showSnackBar(
        success ? ImageGenerationMessages.imageCopied : 'Failed to copy image',
        isSuccess: success,
      );
    } catch (e) {
      debugPrint('❌ Copy error: $e');
      _showSnackBar('Failed to copy image', isSuccess: false);
    }
  }

  /// Delete generated image
  Future<bool> deleteImage(GeneratedImage image) async {
    final confirmed = await _showDeleteConfirmation(image);
    if (!confirmed) return false;

    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    try {
      final success = await imageProvider.deleteImage(image);
      
      _showSnackBar(
        success ? 'Image deleted successfully' : 'Failed to delete image',
        isSuccess: success,
      );
      
      return success;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      _showSnackBar('Failed to delete image', isSuccess: false);
      return false;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(GeneratedImage image) async {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    try {
      await imageProvider.toggleFavorite(image);
      
      final message = image.isFavorite 
          ? 'Removed from favorites' 
          : 'Added to favorites';
          
      _showSnackBar(message, isSuccess: true);
    } catch (e) {
      debugPrint('❌ Toggle favorite error: $e');
      _showSnackBar('Failed to update favorites', isSuccess: false);
    }
  }

  /// Update generation settings
  void updateSettings({
    ImageSize? size,
    ImageQuality? quality,
    ImageStyle? style,
    AIImageProvider? provider, // Updated to use AIImageProvider
  }) {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    imageProvider.updateSettings(
      size: size,
      quality: quality,
      style: style,
      provider: provider,
    );

    _showSnackBar(ImageGenerationMessages.settingsUpdated, isSuccess: true);
  }

  /// Enhance prompt for better results
  String enhancePrompt(String originalPrompt) {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    final enhancedPrompt = imageProvider.enhancePrompt(originalPrompt);
    
    if (enhancedPrompt != originalPrompt) {
      _showSnackBar(ImageGenerationMessages.promptEnhanced, isSuccess: true);
    }
    
    return enhancedPrompt;
  }

  /// Get usage statistics
  Map<String, dynamic> getUsageStats() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return {
      'isPremium': authProvider.isPremium,
      'remainingImages': authProvider.paymentService.remainingImages,
      'dailyLimit': authProvider.isPremium 
          ? ImageGenerationConstants.premiumImagesPerDay 
          : ImageGenerationConstants.freeImagesPerDay,
      'canGenerate': authProvider.isPremium || authProvider.paymentService.remainingImages > 0,
    };
  }

  /// Get estimated generation cost
  int getEstimatedCost() {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    return imageProvider.getGenerationCost();
  }

  /// Cancel ongoing generation
  void cancelGeneration() {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    imageProvider.cancelGeneration();
    
    _showSnackBar('Generation cancelled', isSuccess: true);
  }

  /// Load user's saved images
  Future<void> loadSavedImages() async {
    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    try {
      await imageProvider.loadSavedImages();
    } catch (e) {
      debugPrint('❌ Load images error: $e');
      _showSnackBar('Failed to load saved images', isSuccess: false);
    }
  }

  /// Clear all generated images
  Future<void> clearAllImages() async {
    final confirmed = await _showClearAllConfirmation();
    if (!confirmed) return;

    final imageProvider = Provider.of<ImageGenerationProvider>(context, listen: false);
    
    try {
      await imageProvider.clearAllImages();
      _showSnackBar('All images cleared successfully', isSuccess: true);
    } catch (e) {
      debugPrint('❌ Clear all error: $e');
      _showSnackBar('Failed to clear images', isSuccess: false);
    }
  }

  // Private helper methods

  void _showUsageLimitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('Daily Limit Reached')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You\'ve reached your daily image generation limit for free users.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Premium for:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Unlimited image generation\n• Higher quality options\n• Advanced settings\n• Priority support',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(GeneratedImage image) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this generated image?'),
            const SizedBox(height: 12),
            Text(
              'Prompt: "${image.prompt.length > 50 ? '${image.prompt.substring(0, 50)}...' : image.prompt}"',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<bool> _showClearAllConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Clear All Images'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete all generated images?'),
            SizedBox(height: 12),
            Text(
              'This will permanently delete all your generated images and cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isSuccess 
            ? Colors.green.shade600 
            : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isSuccess ? 2 : 4),
      ),
    );
  }
}