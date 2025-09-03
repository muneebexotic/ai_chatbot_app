// lib\models\generated_image.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'image_generation_request.dart';

/// Model representing a generated image with all its metadata
class GeneratedImage {
  final String id;
  final String prompt;
  final String? imageUrl; // Cloud URL (optional)
  final Uint8List imageData; // Local image data
  final String? localPath; // Local file path (optional)
  final ImageSize size;
  final ImageQuality quality;
  final ImageStyle style;
  final AIImageProvider provider; // Renamed from ImageProvider to AIImageProvider
  final DateTime createdAt;
  final String? negativePrompt;
  final int? seed;
  final double? guidanceScale;
  final int? steps;
  final bool isFavorite;
  final Map<String, dynamic>? metadata;

  const GeneratedImage({
    required this.id,
    required this.prompt,
    this.imageUrl,
    required this.imageData,
    this.localPath,
    required this.size,
    required this.quality,
    required this.style,
    required this.provider,
    required this.createdAt,
    this.negativePrompt,
    this.seed,
    this.guidanceScale,
    this.steps,
    this.isFavorite = false,
    this.metadata,
  });

  /// Create a copy with modified parameters
  GeneratedImage copyWith({
    String? id,
    String? prompt,
    String? imageUrl,
    Uint8List? imageData,
    String? localPath,
    ImageSize? size,
    ImageQuality? quality,
    ImageStyle? style,
    AIImageProvider? provider,
    DateTime? createdAt,
    String? negativePrompt,
    int? seed,
    double? guidanceScale,
    int? steps,
    bool? isFavorite,
    Map<String, dynamic>? metadata,
  }) {
    return GeneratedImage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      imageUrl: imageUrl ?? this.imageUrl,
      imageData: imageData ?? this.imageData,
      localPath: localPath ?? this.localPath,
      size: size ?? this.size,
      quality: quality ?? this.quality,
      style: style ?? this.style,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      seed: seed ?? this.seed,
      guidanceScale: guidanceScale ?? this.guidanceScale,
      steps: steps ?? this.steps,
      isFavorite: isFavorite ?? this.isFavorite,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for storage (without image data for firestore)
  Map<String, dynamic> toMap({bool includeImageData = false}) {
    final map = {
      'id': id,
      'prompt': prompt,
      'imageUrl': imageUrl,
      'localPath': localPath,
      'size': size.name,
      'quality': quality.name,
      'style': style.name,
      'provider': provider.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'negativePrompt': negativePrompt,
      'seed': seed,
      'guidanceScale': guidanceScale,
      'steps': steps,
      'isFavorite': isFavorite,
      'metadata': metadata,
    };

    if (includeImageData) {
      map['imageData'] = imageData;
    }

    return map;
  }

  /// Create from map (for retrieval from storage)
  factory GeneratedImage.fromMap(Map<String, dynamic> map, {Uint8List? imageData}) {
    final rawTimestamp = map['createdAt'];
    
    DateTime parsedTimestamp;
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now();
    }

    return GeneratedImage(
      id: map['id'] ?? '',
      prompt: map['prompt'] ?? '',
      imageUrl: map['imageUrl'],
      imageData: imageData ?? map['imageData'] ?? Uint8List(0),
      localPath: map['localPath'],
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
      createdAt: parsedTimestamp,
      negativePrompt: map['negativePrompt'],
      seed: map['seed']?.toInt(),
      guidanceScale: map['guidanceScale']?.toDouble(),
      steps: map['steps']?.toInt(),
      isFavorite: map['isFavorite'] ?? false,
      metadata: map['metadata'],
    );
  }

  /// Get human-readable description
  String getDescription() {
    final sizeDesc = size.getDisplayName();
    final qualityDesc = quality.getDisplayName();
    final styleDesc = style.getDisplayName();
    final providerDesc = provider.getDisplayName();
    
    return '$sizeDesc, $qualityDesc quality, $styleDesc style via $providerDesc';
  }

  /// Get file size in bytes (estimated if not available)
  int getEstimatedFileSize() {
    final dimensions = size.getDimensions();
    final pixelCount = dimensions.$1 * dimensions.$2;
    
    // Rough estimation: 3 bytes per pixel for RGB + compression factor
    double compressionFactor = quality == ImageQuality.hd ? 0.8 : 0.5;
    return (pixelCount * 3 * compressionFactor).round();
  }

  /// Get display dimensions string
  String getDimensionsString() {
    final dimensions = size.getDimensions();
    return '${dimensions.$1}×${dimensions.$2}';
  }

  /// Check if image is locally available
  bool get hasLocalData => imageData.isNotEmpty;

  /// Check if image is cloud-stored
  bool get hasCloudUrl => imageUrl != null && imageUrl!.isNotEmpty;

  /// Check if image is cached locally
  bool get hasCachedFile => localPath != null && localPath!.isNotEmpty;

  /// Get the best available image source (prefer cloud for persistence)
  ImageSource get bestSource {
    if (hasCloudUrl) return ImageSource.network;
    if (hasLocalData) return ImageSource.memory;
    if (hasCachedFile) return ImageSource.file;
    return ImageSource.none;
  }

  /// Validate the generated image
  bool isValid() {
    return id.isNotEmpty && 
           prompt.trim().isNotEmpty && 
           (hasLocalData || hasCloudUrl || hasCachedFile);
  }

  /// Get generation parameters summary
  Map<String, dynamic> getParametersSummary() {
    return {
      'size': size.getDisplayName(),
      'quality': quality.getDisplayName(),
      'style': style.getDisplayName(),
      'provider': provider.getDisplayName(),
      'seed': seed,
      'guidanceScale': guidanceScale,
      'steps': steps,
      'negativePrompt': negativePrompt,
    }..removeWhere((key, value) => value == null);
  }

  @override
  String toString() {
    return 'GeneratedImage(id: $id, prompt: "${prompt.substring(0, prompt.length.clamp(0, 50))}...", size: $size, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeneratedImage &&
        other.id == id &&
        other.prompt == prompt &&
        other.size == size &&
        other.quality == quality &&
        other.style == style &&
        other.provider == provider;
  }

  @override
  int get hashCode {
    return Object.hash(id, prompt, size, quality, style, provider);
  }
}

/// Image source types
enum ImageSource {
  memory,
  file,
  network,
  none;

  String getDisplayName() {
    switch (this) {
      case ImageSource.memory:
        return 'Memory';
      case ImageSource.file:
        return 'Cached File';
      case ImageSource.network:
        return 'Cloud Storage';
      case ImageSource.none:
        return 'No Source';
    }
  }
}

/// AI Image generation providers - Renamed from ImageProvider to avoid Flutter conflict
enum AIImageProvider {
  dalle,
  huggingFace,
  stabilityAI,
  midjourney;

  String getDisplayName() {
    switch (this) {
      case AIImageProvider.dalle:
        return 'DALL-E';
      case AIImageProvider.huggingFace:
        return 'Hugging Face';
      case AIImageProvider.stabilityAI:
        return 'Stability AI';
      case AIImageProvider.midjourney:
        return 'Midjourney';
    }
  }

  String getDescription() {
    switch (this) {
      case AIImageProvider.dalle:
        return 'OpenAI\'s DALL-E 3 - High quality, creative interpretations';
      case AIImageProvider.huggingFace:
        return 'Hugging Face Models - Free tier available';
      case AIImageProvider.stabilityAI:
        return 'Stable Diffusion - Open source, customizable';
      case AIImageProvider.midjourney:
        return 'Midjourney - Artistic, stylized images';
    }
  }

  bool get isFree {
    switch (this) {
      case AIImageProvider.huggingFace:
        return true;
      default:
        return false;
    }
  }

  double get costPerImage {
    switch (this) {
      case AIImageProvider.dalle:
        return 0.02;
      case AIImageProvider.huggingFace:
        return 0.0;
      case AIImageProvider.stabilityAI:
        return 0.01;
      case AIImageProvider.midjourney:
        return 0.05;
    }
  }
}