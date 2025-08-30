// lib\services\image_generation_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/image_generation_request.dart';
import '../models/generated_image.dart';

// Extension to add only non-null values
extension MapExtensions on Map<String, dynamic> {
  void addIfNotNull(String key, dynamic value) {
    if (value != null) {
      this[key] = value;
    }
  }
}

class ImageGenerationService {
  // API configuration - move these to environment variables in production
  static const String _openAIApiUrl = 'https://api.openai.com/v1/images/generations';
  static const String _openAIApiKey = 'your_openai_api_key_here';
  
  static const String _hfApiUrl = 'https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-xl-base-1.0';
  static const String _hfApiKey = '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';
  
  static const String _stabilityApiUrl = 'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image';
  static const String _stabilityApiKey = 'your_stability_api_key_here';

  bool _isCancelled = false;

  /// Main generation method with progress callback
  Future<GeneratedImage?> generateImage(
    ImageGenerationRequest request, {
    Function(double)? onProgress,
  }) async {
    _isCancelled = false;
    
    // Validate request
    if (!isPromptSafe(request.prompt)) {
      throw ImageGenerationException('Prompt contains inappropriate content');
    }
    
    if (!request.isValid()) {
      throw ImageGenerationException('Invalid request parameters');
    }

    onProgress?.call(0.1);

    try {
      // Route to appropriate provider based on request
      switch (request.provider) {
        case AIImageProvider.dalle:
          onProgress?.call(0.2);
          return await _generateWithDALLE(request, onProgress);
        
        case AIImageProvider.huggingFace:
          onProgress?.call(0.2);
          return await _generateWithHuggingFace(request, onProgress);
        
        case AIImageProvider.stabilityAI:
          onProgress?.call(0.2);
          return await _generateWithStabilityAI(request, onProgress);
        
        case AIImageProvider.midjourney:
          // Midjourney doesn't have a direct API, so fall back to Stability AI
          onProgress?.call(0.2);
          return await _generateWithStabilityAI(request, onProgress);
      }
    } catch (e) {
      if (_isCancelled) {
        throw ImageGenerationException('Generation was cancelled');
      }
      rethrow;
    }
  }

  /// Generate using OpenAI DALL-E
  Future<GeneratedImage?> _generateWithDALLE(
    ImageGenerationRequest request,
    Function(double)? onProgress,
  ) async {
    try {
      debugPrint('🎨 Generating with DALL-E: ${request.prompt}');
      onProgress?.call(0.3);

      final response = await http.post(
        Uri.parse(_openAIApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAIApiKey',
        },
        body: jsonEncode({
          'prompt': enhancePrompt(request.prompt, request.style),
          'n': 1,
          'size': _mapSizeToDALLE(request.size),
          'quality': request.quality == ImageQuality.hd ? 'hd' : 'standard',
          'style': request.style == ImageStyle.natural ? 'natural' : 'vivid',
        }),
      );

      if (_isCancelled) return null;
      onProgress?.call(0.6);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['data'][0]['url'] as String;
        
        onProgress?.call(0.8);
        
        // Download the image data
        final imageResponse = await http.get(Uri.parse(imageUrl));
        if (imageResponse.statusCode == 200) {
          onProgress?.call(1.0);
          
          return GeneratedImage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            prompt: request.prompt,
            imageUrl: imageUrl,
            imageData: imageResponse.bodyBytes,
            size: request.size,
            quality: request.quality,
            style: request.style,
            provider: AIImageProvider.dalle,
            createdAt: DateTime.now(),
            negativePrompt: request.negativePrompt,
            seed: request.seed,
            guidanceScale: request.guidanceScale,
            steps: request.steps,
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw ImageGenerationException('DALL-E API Error: ${errorData['error']['message'] ?? response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ DALL-E generation failed: $e');
      rethrow;
    }
    
    return null;
  }

  /// Generate using Hugging Face
  Future<GeneratedImage?> _generateWithHuggingFace(
    ImageGenerationRequest request,
    Function(double)? onProgress,
  ) async {
    try {
      debugPrint('🎨 Generating with Hugging Face: ${request.prompt}');
      onProgress?.call(0.3);

      final dimensions = request.size.getDimensions();
      
      // Build parameters without null values
      Map<String, dynamic> parameters = {};
      parameters.addIfNotNull('width', dimensions.$1);
      parameters.addIfNotNull('height', dimensions.$2);
      parameters.addIfNotNull('num_inference_steps', request.steps ?? (request.quality == ImageQuality.hd ? 50 : 25));
      parameters.addIfNotNull('guidance_scale', request.guidanceScale ?? 7.5);
      parameters.addIfNotNull('seed', request.seed);
      parameters.addIfNotNull('negative_prompt', request.negativePrompt);

      final response = await http.post(
        Uri.parse(_hfApiUrl),
        headers: {
          'Authorization': 'Bearer $_hfApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': enhancePrompt(request.prompt, request.style),
          if (parameters.isNotEmpty) 'parameters': parameters,
        }),
      );

      if (_isCancelled) return null;
      onProgress?.call(0.8);

      if (response.statusCode == 200) {
        onProgress?.call(1.0);
        
        return GeneratedImage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          prompt: request.prompt,
          imageUrl: null,
          imageData: response.bodyBytes,
          size: request.size,
          quality: request.quality,
          style: request.style,
          provider: AIImageProvider.huggingFace,
          createdAt: DateTime.now(),
          negativePrompt: request.negativePrompt,
          seed: request.seed,
          guidanceScale: request.guidanceScale,
          steps: request.steps,
        );
      } else {
        final errorMessage = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw ImageGenerationException('Hugging Face API Error: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      debugPrint('❌ Hugging Face generation failed: $e');
      rethrow;
    }
  }

  /// Generate using Stability AI
  Future<GeneratedImage?> _generateWithStabilityAI(
    ImageGenerationRequest request,
    Function(double)? onProgress,
  ) async {
    try {
      debugPrint('🎨 Generating with Stability AI: ${request.prompt}');
      onProgress?.call(0.3);

      final dimensions = request.size.getDimensions();
      final response = await http.post(
        Uri.parse(_stabilityApiUrl),
        headers: {
          'Authorization': 'Bearer $_stabilityApiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'text_prompts': [
            {
              'text': enhancePrompt(request.prompt, request.style),
              'weight': 1.0,
            },
            if (request.negativePrompt != null)
              {
                'text': request.negativePrompt,
                'weight': -1.0,
              }
          ],
          'cfg_scale': request.guidanceScale ?? 7.0,
          'width': dimensions.$1,
          'height': dimensions.$2,
          'steps': request.steps ?? (request.quality == ImageQuality.hd ? 50 : 30),
          'samples': 1,
          'seed': request.seed,
        }),
      );

      if (_isCancelled) return null;
      onProgress?.call(0.8);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64Image = data['artifacts'][0]['base64'] as String;
        final imageData = base64Decode(base64Image);
        
        onProgress?.call(1.0);
        
        return GeneratedImage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          prompt: request.prompt,
          imageUrl: null,
          imageData: imageData,
          size: request.size,
          quality: request.quality,
          style: request.style,
          provider: AIImageProvider.stabilityAI,
          createdAt: DateTime.now(),
          negativePrompt: request.negativePrompt,
          seed: request.seed,
          guidanceScale: request.guidanceScale,
          steps: request.steps,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw ImageGenerationException('Stability AI Error: ${errorData['message'] ?? response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Stability AI generation failed: $e');
      rethrow;
    }
  }

  /// Cancel ongoing generation
  void cancelGeneration() {
    _isCancelled = true;
    debugPrint('🚫 Image generation cancelled');
  }

  /// Validate prompt for content policy
  bool isPromptSafe(String prompt) {
    final lowercasePrompt = prompt.toLowerCase();
    
    // Basic content filtering - extend as needed
    final restrictedWords = [
      'nude', 'naked', 'violence', 'gore', 'explicit',
      'nsfw', 'adult', 'sexual', 'inappropriate', 'violent',
      'blood', 'death', 'kill', 'weapon', 'drug'
    ];
    
    for (final word in restrictedWords) {
      if (lowercasePrompt.contains(word)) {
        return false;
      }
    }
    
    return prompt.trim().isNotEmpty && prompt.length >= 3 && prompt.length <= 1000;
  }

  /// Enhance user prompt based on style
  String enhancePrompt(String userPrompt, ImageStyle style) {
    final basePrompt = userPrompt.trim();
    
    switch (style) {
      case ImageStyle.natural:
        return '$basePrompt, natural lighting, realistic, high quality, detailed';
      case ImageStyle.vivid:
        return '$basePrompt, vibrant colors, dramatic lighting, artistic, creative, high contrast';
      case ImageStyle.artistic:
        return '$basePrompt, artistic style, creative interpretation, beautiful composition, trending on artstation';
      case ImageStyle.photographic:
        return '$basePrompt, photorealistic, professional photography, sharp details, perfect lighting, studio quality';
    }
  }

  /// Get provider availability and costs
  Map<String, dynamic> getProviderInfo() {
    return {
      'dalle': {
        'available': true,
        'cost_per_image': 0.02,
        'cost_per_hd': 0.04,
        'max_size': '1792x1024',
      },
      'huggingFace': {
        'available': true,
        'cost_per_image': 0.0,
        'free_tier': true,
        'rate_limit': 'Limited requests per hour',
      },
      'stabilityAI': {
        'available': true,
        'cost_per_image': 0.01,
        'max_size': '1536x1536',
      },
      'midjourney': {
        'available': false,
        'note': 'No direct API available',
      },
    };
  }

  /// Map size enum to DALL-E format
  String _mapSizeToDALLE(ImageSize size) {
    switch (size) {
      case ImageSize.small:
        return '1024x1024'; // DALL-E 3 minimum
      case ImageSize.medium:
        return '1024x1024';
      case ImageSize.large:
        return '1024x1024';
      case ImageSize.wide:
        return '1792x1024';
      case ImageSize.tall:
        return '1024x1792';
    }
  }

  /// Dispose resources
  void dispose() {
    _isCancelled = true;
  }
}

/// Custom exception for image generation errors
class ImageGenerationException implements Exception {
  final String message;
  
  ImageGenerationException(this.message);
  
  @override
  String toString() => 'ImageGenerationException: $message';
}