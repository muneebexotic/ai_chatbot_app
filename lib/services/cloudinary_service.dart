// lib\services\cloudinary_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  final String cloudName = 'drbt1cndv';
  final String uploadPreset = 'unsigned_preset';

  Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        return data['secure_url']; // This is the image URL
      } else {
        debugPrint('Upload failed: ${response.statusCode}');
        debugPrint('Response body: $resBody');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Upload image from bytes data
  Future<String?> uploadImageBytes({
    required Uint8List imageBytes,
    required String publicId,
    String? folder,
    Map<String, dynamic>? transformation,
  }) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['public_id'] = publicId;

      // Add folder if provided
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Add transformation parameters if provided
      if (transformation != null && transformation.isNotEmpty) {
        final transformationString = transformation.entries
            .map((entry) => '${entry.key}_${entry.value}')
            .join(',');
        request.fields['transformation'] = transformationString;
      }

      // Add the image bytes as a multipart file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: '$publicId.png',
        ),
      );

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        debugPrint('✅ Image uploaded successfully: ${data['secure_url']}');
        return data['secure_url']; // This is the image URL
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode}');
        debugPrint('Response body: $resBody');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error uploading image bytes: $e');
      return null;
    }
  }

  /// Delete image from Cloudinary
  Future<bool> deleteImage(String publicId) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['public_id'] = publicId;

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(resBody);
        debugPrint('✅ Image deleted successfully: $publicId');
        return data['result'] == 'ok';
      } else {
        debugPrint('❌ Delete failed: ${response.statusCode}');
        debugPrint('Response body: $resBody');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Get image info from Cloudinary
  Future<Map<String, dynamic>?> getImageInfo(String publicId) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      final response = await http.get(
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/resources/image/upload/$publicId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ Failed to get image info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting image info: $e');
      return null;
    }
  }
}