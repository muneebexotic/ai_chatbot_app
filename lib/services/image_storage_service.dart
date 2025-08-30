// lib\services\image_storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/generated_image.dart';
import '../services/cloudinary_service.dart';

class ImageStorageService {
  static const String _cacheFolder = 'generated_images';
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB cache limit
  static const int _maxCacheAge = 30; // 30 days
  
  late final CloudinaryService _cloudinaryService;
  
  ImageStorageService() {
    _cloudinaryService = CloudinaryService();
  }

  /// Save image to local cache
  Future<String?> saveImageToCache(GeneratedImage image) async {
    try {
      final directory = await _getCacheDirectory();
      final fileName = '${image.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = path.join(directory.path, fileName);
      
      final file = File(filePath);
      await file.writeAsBytes(image.imageData);
      
      debugPrint('💾 Image cached locally: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ Failed to cache image: $e');
      return null;
    }
  }

  /// Load image from local cache
  Future<Uint8List?> loadImageFromCache(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('❌ Failed to load cached image: $e');
    }
    return null;
  }

  /// Upload image to cloud storage (Cloudinary)
  Future<String?> uploadImageToCloud(GeneratedImage image, String userId) async {
    try {
      debugPrint('☁️ Uploading image to cloud: ${image.id}');
      
      final publicId = 'generated_images/${userId}/${image.id}_${DateTime.now().millisecondsSinceEpoch}';
      
      final cloudUrl = await _cloudinaryService.uploadImageBytes(
        imageBytes: image.imageData,
        publicId: publicId,
        folder: 'ai_chatbot/generated_images',
      );

      if (cloudUrl != null) {
        debugPrint('✅ Image uploaded to cloud: $cloudUrl');
        return cloudUrl;
      }
    } catch (e) {
      debugPrint('❌ Failed to upload image to cloud: $e');
    }
    return null;
  }

  /// Get cached images for a user
  Future<List<String>> getCachedImagePaths() async {
    try {
      final directory = await _getCacheDirectory();
      if (!await directory.exists()) {
        return [];
      }

      final files = await directory.list().toList();
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.png') || file.path.endsWith('.jpg'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get cached images: $e');
      return [];
    }
  }

  /// Clean up old cached images
  Future<void> cleanupCache() async {
    try {
      final directory = await _getCacheDirectory();
      if (!await directory.exists()) return;

      final files = await directory.list().toList();
      final now = DateTime.now();
      int totalSize = 0;
      
      // Calculate total cache size and remove old files
      for (final file in files.whereType<File>()) {
        final stat = await file.stat();
        final age = now.difference(stat.modified).inDays;
        
        if (age > _maxCacheAge) {
          await file.delete();
          debugPrint('🗑️ Deleted old cached image: ${path.basename(file.path)}');
        } else {
          totalSize += stat.size;
        }
      }

      // If cache is still too large, remove oldest files
      if (totalSize > _maxCacheSize) {
        await _cleanupBySize(directory);
      }
      
      debugPrint('🧹 Cache cleanup completed. Size: ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB');
    } catch (e) {
      debugPrint('❌ Cache cleanup failed: $e');
    }
  }

  /// Clean up cache by removing oldest files until under size limit
  Future<void> _cleanupBySize(Directory directory) async {
    try {
      final files = await directory.list().toList();
      final fileStats = <MapEntry<File, FileStat>>[];
      
      // Get file stats
      for (final file in files.whereType<File>()) {
        final stat = await file.stat();
        fileStats.add(MapEntry(file, stat));
      }
      
      // Sort by modification date (oldest first)
      fileStats.sort((a, b) => a.value.modified.compareTo(b.value.modified));
      
      int currentSize = fileStats.fold(0, (sum, entry) => sum + entry.value.size);
      
      // Remove oldest files until under limit
      for (final entry in fileStats) {
        if (currentSize <= _maxCacheSize) break;
        
        await entry.key.delete();
        currentSize -= entry.value.size;
        debugPrint('🗑️ Deleted cached image to free space: ${path.basename(entry.key.path)}');
      }
    } catch (e) {
      debugPrint('❌ Size-based cleanup failed: $e');
    }
  }

  /// Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, _cacheFolder));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final directory = await _getCacheDirectory();
      if (!await directory.exists()) {
        return {
          'totalFiles': 0,
          'totalSize': 0,
          'totalSizeMB': 0.0,
          'oldestFile': null,
          'newestFile': null,
        };
      }

      final files = await directory.list().toList();
      final imageFiles = files.whereType<File>().where((file) => 
          file.path.endsWith('.png') || file.path.endsWith('.jpg')).toList();
      
      if (imageFiles.isEmpty) {
        return {
          'totalFiles': 0,
          'totalSize': 0,
          'totalSizeMB': 0.0,
          'oldestFile': null,
          'newestFile': null,
        };
      }

      int totalSize = 0;
      DateTime? oldestDate;
      DateTime? newestDate;

      for (final file in imageFiles) {
        final stat = await file.stat();
        totalSize += stat.size;
        
        if (oldestDate == null || stat.modified.isBefore(oldestDate)) {
          oldestDate = stat.modified;
        }
        if (newestDate == null || stat.modified.isAfter(newestDate)) {
          newestDate = stat.modified;
        }
      }

      return {
        'totalFiles': imageFiles.length,
        'totalSize': totalSize,
        'totalSizeMB': totalSize / 1024 / 1024,
        'oldestFile': oldestDate,
        'newestFile': newestDate,
        'maxSizeMB': _maxCacheSize / 1024 / 1024,
        'maxAge': _maxCacheAge,
      };
    } catch (e) {
      debugPrint('❌ Failed to get cache stats: $e');
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'totalSizeMB': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Clear all cached images
  Future<bool> clearCache() async {
    try {
      final directory = await _getCacheDirectory();
      if (!await directory.exists()) return true;

      final files = await directory.list().toList();
      for (final file in files) {
        await file.delete();
      }

      debugPrint('🧹 All cached images cleared');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to clear cache: $e');
      return false;
    }
  }

  /// Check if we have space for new image
  Future<bool> hasSpaceForImage(int imageSize) async {
    final stats = await getCacheStats();
    final currentSize = stats['totalSize'] as int;
    return (currentSize + imageSize) <= _maxCacheSize;
  }

  /// Compress image if needed
  Future<Uint8List> optimizeImageData(Uint8List imageData, {int maxSize = 2 * 1024 * 1024}) async {
    // If image is already small enough, return as-is
    if (imageData.length <= maxSize) {
      return imageData;
    }

    // For Flutter web/mobile, you might want to use image compression packages
    // like flutter_image_compress or similar
    debugPrint('⚠️ Image size (${imageData.length} bytes) exceeds limit, consider compression');
    
    // For now, return original - implement compression as needed
    return imageData;
  }
}