// lib\providers\image_generation_provider.dart
import 'dart:typed_data';

import 'package:ai_chatbot_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/image_generation_request.dart';
import '../models/generated_image.dart';
import '../services/image_generation_service.dart';
import '../services/image_storage_service.dart';
import '../constants/image_generation_constants.dart';

class ImageGenerationProvider with ChangeNotifier {
  final ImageGenerationService _generationService = ImageGenerationService();
  final ImageStorageService _storageService = ImageStorageService();
  
  // Generation state
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;
  
  double _generationProgress = 0.0;
  double get generationProgress => _generationProgress;
  
  String _generationStatus = ImageGenerationMessages.readyStatus;
  String get generationStatus => _generationStatus;
  
  // Current request and result
  ImageGenerationRequest? _currentRequest;
  ImageGenerationRequest? get currentRequest => _currentRequest;
  
  GeneratedImage? _currentImage;
  GeneratedImage? get currentImage => _currentImage;
  
  // Generated images history
  final List<GeneratedImage> _generatedImages = [];
  List<GeneratedImage> get generatedImages => List.unmodifiable(_generatedImages);
  
  // Error handling
  String? _lastError;
  String? get lastError => _lastError;
  
  // Settings
  ImageSize _selectedSize = ImageSize.medium;
  ImageSize get selectedSize => _selectedSize;
  
  ImageQuality _selectedQuality = ImageQuality.standard;
  ImageQuality get selectedQuality => _selectedQuality;
  
  ImageStyle _selectedStyle = ImageStyle.natural;
  ImageStyle get selectedStyle => _selectedStyle;
  
  AIImageProvider _selectedProvider = AIImageProvider.huggingFace; // Updated to AIImageProvider
  AIImageProvider get selectedProvider => _selectedProvider;

  String? _selectedHfModel = ImageGenerationConstants.huggingFaceModels[0]; // Added default HF model
  String? get selectedHfModel => _selectedHfModel;

  /// Update generation settings
  void updateSettings({
    ImageSize? size,
    ImageQuality? quality,
    ImageStyle? style,
    AIImageProvider? provider, // Updated parameter type
    String? hfModel,
  }) {
    bool hasChanges = false;
    
    if (size != null && size != _selectedSize) {
      _selectedSize = size;
      hasChanges = true;
    }
    
    if (quality != null && quality != _selectedQuality) {
      _selectedQuality = quality;
      hasChanges = true;
    }
    
    if (style != null && style != _selectedStyle) {
      _selectedStyle = style;
      hasChanges = true;
    }
    
    if (provider != null && provider != _selectedProvider) {
      _selectedProvider = provider;
      hasChanges = true;
    }
    
    if (hfModel != null && hfModel != _selectedHfModel) {
      _selectedHfModel = hfModel;
      hasChanges = true;
    }
    
    if (hasChanges) {
      notifyListeners();
    }
  }

  /// Generate image from prompt
  Future<GeneratedImage?> generateImage(BuildContext context, String prompt, {
    String? negativePrompt,
    int? seed,
    double? guidanceScale,
    int? steps,
    String? hfModel, // Added optional hfModel param
  }) async {
    if (_isGenerating) {
      debugPrint('⚠️ Image generation already in progress');
      return null;
    }

    // Validate prompt
    if (prompt.trim().isEmpty) {
      _setError(ImageGenerationErrors.invalidPrompt);
      return null;
    }

    if (prompt.length < ImageGenerationConstants.minPromptLength) {
      _setError(ImageGenerationErrors.promptTooShort);
      return null;
    }

    if (prompt.length > ImageGenerationConstants.maxPromptLength) {
      _setError(ImageGenerationErrors.promptTooLong);
      return null;
    }

    // Create request
    final request = ImageGenerationRequest(
      prompt: prompt.trim(),
      size: _selectedSize,
      quality: _selectedQuality,
      style: _selectedStyle,
      provider: _selectedProvider, // Using updated provider
      hfModel: hfModel ?? _selectedHfModel, // Use param or selected
      negativePrompt: negativePrompt?.trim(),
      seed: seed,
      guidanceScale: guidanceScale,
      steps: steps,
    );

    _currentRequest = request;
    _setGenerating(true);
    _setError(null);
    _setStatus(ImageGenerationMessages.generationStarted);
    _setProgress(0.0);

    try {
      // Generate image with progress tracking
      final generatedImage = await _generationService.generateImage(
        request,
        onProgress: _updateProgress,
      );

      if (generatedImage != null) {
        // Get user ID from AuthProvider
        final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? 'anonymous';
        
        // Upload to cloud
        final cloudUrl = await _storageService.uploadImageToCloud(generatedImage, userId);
        GeneratedImage updatedImage = generatedImage;
        if (cloudUrl != null) {
          updatedImage = generatedImage.copyWith(imageUrl: cloudUrl);
          // Optional: Clean up local bytes to save memory, since we have URL
          updatedImage = updatedImage.copyWith(imageData: Uint8List(0));
        } else {
          debugPrint('⚠️ Cloud upload failed, falling back to local only');
        }

        // Save to local cache as fallback
        final localPath = await _storageService.saveImageToCache(updatedImage);
        if (localPath != null) {
          updatedImage = updatedImage.copyWith(localPath: localPath);
        }

        _currentImage = updatedImage;
        _generatedImages.insert(0, updatedImage);
        
        // Save to local storage
        try {
          await _storageService.saveImageToCache(updatedImage);
        } catch (e) {
          debugPrint('⚠️ Failed to save image locally: $e');
          // Don't fail the whole operation if local save fails
        }
        
        _setStatus(ImageGenerationMessages.generationCompleted);
        _setProgress(1.0);
        
        debugPrint('✅ Image generated successfully: ${updatedImage.id}');
        return updatedImage;
      } else {
        _setError(ImageGenerationErrors.apiError);
        return null;
      }
    } catch (e) {
      debugPrint('❌ Image generation failed: $e');
      _setError(_getErrorMessage(e));
      return null;
    } finally {
      _setGenerating(false);
    }
  }

  /// Regenerate the last image with same parameters
  Future<GeneratedImage?> regenerateImage(BuildContext context) async {
    if (_currentRequest == null) {
      _setError('No previous request to regenerate');
      return null;
    }

    return generateImage(
      context,
      _currentRequest!.prompt,
      negativePrompt: _currentRequest!.negativePrompt,
      seed: _currentRequest!.seed,
      guidanceScale: _currentRequest!.guidanceScale,
      steps: _currentRequest!.steps,
      hfModel: _currentRequest!.hfModel, // Pass hfModel
    );
  }

  /// Enhance a prompt for better results
  String enhancePrompt(String originalPrompt) {
    if (originalPrompt.trim().isEmpty) return originalPrompt;

    final prompt = originalPrompt.trim();
    final style = _selectedStyle;
    final quality = _selectedQuality;

    // Add style modifiers
    String enhanced = prompt;
    
    // Add quality modifiers for HD
    if (quality == ImageQuality.hd) {
      const qualityWords = ['highly detailed', 'ultra high resolution', '8K quality'];
      final hasQualityModifier = qualityWords.any((word) => 
        enhanced.toLowerCase().contains(word.toLowerCase()));
      
      if (!hasQualityModifier) {
        enhanced = '$enhanced, highly detailed, ultra high resolution';
      }
    }

    // Add style-specific enhancements
    switch (style) {
      case ImageStyle.photographic:
        if (!enhanced.toLowerCase().contains('photo')) {
          enhanced = '$enhanced, professional photography, studio lighting';
        }
        break;
      case ImageStyle.artistic:
        if (!enhanced.toLowerCase().contains('art')) {
          enhanced = '$enhanced, artistic masterpiece, trending on artstation';
        }
        break;
      case ImageStyle.vivid:
        if (!enhanced.toLowerCase().contains('vivid') && !enhanced.toLowerCase().contains('vibrant')) {
          enhanced = '$enhanced, vivid colors, dramatic lighting';
        }
        break;
      case ImageStyle.natural:
        // Keep natural for natural style
        break;
    }

    return enhanced;
  }

  /// Save image to device gallery
  Future<bool> saveImageToGallery(GeneratedImage image) async {
    try {
      // Implement gallery save functionality through storage service
      final success = await _storageService.saveImageToCache(image);
      if (success != null) {
        _setStatus(ImageGenerationMessages.imageSaved);
        return true;
      } else {
        _setError(ImageGenerationErrors.storageError);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to save image to gallery: $e');
      _setError(ImageGenerationErrors.storageError);
      return false;
    }
  }

  /// Share generated image
  Future<bool> shareImage(GeneratedImage image) async {
    try {
      // For now, save to cache as a proxy for sharing
      // You can implement proper sharing later with share_plus package
      final success = await _storageService.saveImageToCache(image);
      if (success != null) {
        _setStatus(ImageGenerationMessages.imageShared);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to share image: $e');
      return false;
    }
  }

  /// Copy image to clipboard
  Future<bool> copyImageToClipboard(GeneratedImage image) async {
    try {
      // Implement clipboard functionality
      // For now, return true as placeholder
      _setStatus(ImageGenerationMessages.imageCopied);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to copy image: $e');
      return false;
    }
  }

  /// Delete generated image
  Future<bool> deleteImage(GeneratedImage image) async {
    try {
      // Remove from local list
      _generatedImages.removeWhere((img) => img.id == image.id);
      
      if (_currentImage?.id == image.id) {
        _currentImage = null;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete image: $e');
      return false;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(GeneratedImage image) async {
    final index = _generatedImages.indexWhere((img) => img.id == image.id);
    if (index != -1) {
      final updatedImage = image.copyWith(isFavorite: !image.isFavorite);
      _generatedImages[index] = updatedImage;
      
      if (_currentImage?.id == image.id) {
        _currentImage = updatedImage;
      }
      
      notifyListeners();
    }
  }

  /// Load saved images
  Future<void> loadSavedImages() async {
    try {
      final cachedPaths = await _storageService.getCachedImagePaths();
      // Load images from cache paths
      // This is a simplified implementation
      debugPrint('Loaded ${cachedPaths.length} cached images');
    } catch (e) {
      debugPrint('❌ Failed to load saved images: $e');
    }
  }

  /// Clear all generated images
  Future<void> clearAllImages() async {
    try {
      await _storageService.clearCache();
      _generatedImages.clear();
      _currentImage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to clear images: $e');
    }
  }

  /// Get generation cost estimate
  int getGenerationCost() {
    final request = ImageGenerationRequest(
      prompt: '',
      size: _selectedSize,
      quality: _selectedQuality,
      style: _selectedStyle,
      provider: _selectedProvider,
      hfModel: _selectedHfModel,
    );
    return request.getEstimatedCost();
  }

  /// Cancel ongoing generation
  void cancelGeneration() {
    if (_isGenerating) {
      _generationService.cancelGeneration();
      _setGenerating(false);
      _setStatus(ImageGenerationMessages.readyStatus);
      _setProgress(0.0);
    }
  }

  // Private helper methods
  void _setGenerating(bool generating) {
    _isGenerating = generating;
    notifyListeners();
  }

  void _setProgress(double progress) {
    _generationProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  void _setStatus(String status) {
    _generationStatus = status;
    notifyListeners();
  }

  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      _setStatus(ImageGenerationMessages.errorStatus);
    }
    notifyListeners();
  }

  void _updateProgress(double progress) {
    _setProgress(progress);
    
    // Update status based on progress
    final percentage = (progress * 100).round();
    _setStatus(ImageGenerationMessages.getGenerationProgress(percentage));
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('network') || error.toString().contains('connection')) {
      return ImageGenerationErrors.networkError;
    } else if (error.toString().contains('timeout')) {
      return ImageGenerationErrors.apiError;
    } else if (error.toString().contains('inappropriate') || error.toString().contains('content')) {
      return ImageGenerationErrors.inappropriateContent;
    } else if (error.toString().contains('limit') || error.toString().contains('quota')) {
      return ImageGenerationErrors.usageLimitExceeded;
    } else {
      return ImageGenerationErrors.unknownError;
    }
  }

  /// Clear error state
  void clearError() {
    _setError(null);
    _setStatus(ImageGenerationMessages.readyStatus);
  }

  /// Get favorite images
  List<GeneratedImage> get favoriteImages {
    return _generatedImages.where((image) => image.isFavorite).toList();
  }

  /// Get images by style
  List<GeneratedImage> getImagesByStyle(ImageStyle style) {
    return _generatedImages.where((image) => image.style == style).toList();
  }

  /// Get images by size
  List<GeneratedImage> getImagesBySize(ImageSize size) {
    return _generatedImages.where((image) => image.size == size).toList();
  }

  /// Get images by provider
  List<GeneratedImage> getImagesByProvider(AIImageProvider provider) {
    return _generatedImages.where((image) => image.provider == provider).toList();
  }

  /// Get recent images (last 10)
  List<GeneratedImage> get recentImages {
    return _generatedImages.take(10).toList();
  }

  @override
  void dispose() {
    _generationService.dispose();
    super.dispose();
  }
}