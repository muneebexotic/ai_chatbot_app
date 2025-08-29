import 'generated_image.dart'; // Import for AIImageProvider

/// Model representing a request to generate an image
class ImageGenerationRequest {
  final String prompt;
  final ImageSize size;
  final ImageQuality quality;
  final ImageStyle style;
  final AIImageProvider provider; // Added provider field
  final String? negativePrompt;
  final int? seed;
  final double? guidanceScale;
  final int? steps;

  const ImageGenerationRequest({
    required this.prompt,
    this.size = ImageSize.medium,
    this.quality = ImageQuality.standard,
    this.style = ImageStyle.natural,
    this.provider = AIImageProvider.huggingFace, // Default provider
    this.negativePrompt,
    this.seed,
    this.guidanceScale,
    this.steps,
  });

  /// Create a copy with modified parameters
  ImageGenerationRequest copyWith({
    String? prompt,
    ImageSize? size,
    ImageQuality? quality,
    ImageStyle? style,
    AIImageProvider? provider,
    String? negativePrompt,
    int? seed,
    double? guidanceScale,
    int? steps,
  }) {
    return ImageGenerationRequest(
      prompt: prompt ?? this.prompt,
      size: size ?? this.size,
      quality: quality ?? this.quality,
      style: style ?? this.style,
      provider: provider ?? this.provider,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      seed: seed ?? this.seed,
      guidanceScale: guidanceScale ?? this.guidanceScale,
      steps: steps ?? this.steps,
    );
  }

  /// Convert to map for API calls
  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'size': size.name,
      'quality': quality.name,
      'style': style.name,
      'provider': provider.name,
      'negative_prompt': negativePrompt,
      'seed': seed,
      'guidance_scale': guidanceScale,
      'steps': steps,
    };
  }

  /// Create from map (for storage/retrieval)
  factory ImageGenerationRequest.fromMap(Map<String, dynamic> map) {
    return ImageGenerationRequest(
      prompt: map['prompt'] ?? '',
      size: ImageSize.values.firstWhere(
        (e) => e.name == map['size'], 
        orElse: () => ImageSize.medium,
      ),
      quality: ImageQuality.values.firstWhere(
        (e) => e.name == map['quality'], 
        orElse: () => ImageQuality.standard,
      ),
      style: ImageStyle.values.firstWhere(
        (e) => e.name == map['style'], 
        orElse: () => ImageStyle.natural,
      ),
      provider: AIImageProvider.values.firstWhere(
        (e) => e.name == map['provider'], 
        orElse: () => AIImageProvider.huggingFace,
      ),
      negativePrompt: map['negative_prompt'],
      seed: map['seed']?.toInt(),
      guidanceScale: map['guidance_scale']?.toDouble(),
      steps: map['steps']?.toInt(),
    );
  }

  /// Validate the request
  bool isValid() {
    return prompt.trim().isNotEmpty && 
           prompt.length >= 3 && 
           prompt.length <= 1000;
  }

  /// Get estimated cost in credits/tokens
  int getEstimatedCost() {
    int baseCost = provider.costPerImage.round();
    
    // Size multiplier
    switch (size) {
      case ImageSize.small:
        baseCost *= 1;
        break;
      case ImageSize.medium:
        baseCost *= 2;
        break;
      case ImageSize.large:
        baseCost *= 4;
        break;
      case ImageSize.wide:
      case ImageSize.tall:
        baseCost *= 3;
        break;
    }
    
    // Quality multiplier
    if (quality == ImageQuality.hd) {
      baseCost *= 2;
    }
    
    return baseCost == 0 ? 1 : baseCost; // Ensure at least 1 credit for free providers
  }

  /// Get human-readable description
  String getDescription() {
    final sizeDesc = size.getDisplayName();
    final qualityDesc = quality.getDisplayName();
    final styleDesc = style.getDisplayName();
    final providerDesc = provider.getDisplayName();
    
    return '$sizeDesc, $qualityDesc quality, $styleDesc style via $providerDesc';
  }

  @override
  String toString() {
    return 'ImageGenerationRequest(prompt: "$prompt", size: $size, quality: $quality, style: $style, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageGenerationRequest &&
        other.prompt == prompt &&
        other.size == size &&
        other.quality == quality &&
        other.style == style &&
        other.provider == provider &&
        other.negativePrompt == negativePrompt &&
        other.seed == seed &&
        other.guidanceScale == guidanceScale &&
        other.steps == steps;
  }

  @override
  int get hashCode {
    return Object.hash(
      prompt,
      size,
      quality,
      style,
      provider,
      negativePrompt,
      seed,
      guidanceScale,
      steps,
    );
  }
}

/// Supported image sizes
enum ImageSize {
  small,
  medium,
  large,
  wide,
  tall;

  String getDisplayName() {
    switch (this) {
      case ImageSize.small:
        return 'Small (512×512)';
      case ImageSize.medium:
        return 'Medium (768×768)';
      case ImageSize.large:
        return 'Large (1024×1024)';
      case ImageSize.wide:
        return 'Wide (1344×768)';
      case ImageSize.tall:
        return 'Tall (768×1344)';
    }
  }

  (int, int) getDimensions() {
    switch (this) {
      case ImageSize.small:
        return (512, 512);
      case ImageSize.medium:
        return (768, 768);
      case ImageSize.large:
        return (1024, 1024);
      case ImageSize.wide:
        return (1344, 768);
      case ImageSize.tall:
        return (768, 1344);
    }
  }
}

/// Image quality options
enum ImageQuality {
  standard,
  hd;

  String getDisplayName() {
    switch (this) {
      case ImageQuality.standard:
        return 'Standard';
      case ImageQuality.hd:
        return 'HD';
    }
  }

  String getDescription() {
    switch (this) {
      case ImageQuality.standard:
        return 'Good quality, faster generation';
      case ImageQuality.hd:
        return 'High quality, more detailed';
    }
  }
}

/// Image style options
enum ImageStyle {
  natural,
  vivid,
  artistic,
  photographic;

  String getDisplayName() {
    switch (this) {
      case ImageStyle.natural:
        return 'Natural';
      case ImageStyle.vivid:
        return 'Vivid';
      case ImageStyle.artistic:
        return 'Artistic';
      case ImageStyle.photographic:
        return 'Photographic';
    }
  }

  String getDescription() {
    switch (this) {
      case ImageStyle.natural:
        return 'Realistic, natural lighting';
      case ImageStyle.vivid:
        return 'Vibrant colors, dramatic contrast';
      case ImageStyle.artistic:
        return 'Creative, stylized interpretation';
      case ImageStyle.photographic:
        return 'Professional photography style';
    }
  }
}