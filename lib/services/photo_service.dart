import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoService {
  static final PhotoService _instance = PhotoService._internal();
  factory PhotoService() => _instance;
  PhotoService._internal();

  final ImagePicker _picker = ImagePicker();

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      // Check camera permission
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        throw Exception('Camera permission denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from camera: $e');
      rethrow;
    }
  }

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      // Check storage permission (for Android < 13)
      if (Platform.isAndroid) {
        final storagePermission = await Permission.storage.request();
        if (!storagePermission.isGranted) {
          final photosPermission = await Permission.photos.request();
          if (!photosPermission.isGranted) {
            throw Exception('Storage permission denied');
          }
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      rethrow;
    }
  }

  // Generate random avatar using DiceBear API
  Future<String> generateRandomAvatar({String? seed}) async {
    try {
      // Generate a random seed if not provided
      final avatarSeed = seed ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Using DiceBear Avataaars style
      final url = 'https://api.dicebear.com/7.x/avataaars/svg?seed=$avatarSeed';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Return the URL for the avatar
        return url;
      } else {
        throw Exception('Failed to generate avatar: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating random avatar: $e');
      // Return a fallback URL
      return 'https://api.dicebear.com/7.x/avataaars/svg?seed=fallback';
    }
  }

  // Get avatar as bytes for local storage (optional)
  Future<Uint8List?> getAvatarBytes(String avatarUrl) async {
    try {
      final response = await http.get(Uri.parse(avatarUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('Error getting avatar bytes: $e');
      return null;
    }
  }

  // Show photo selection options dialog
  Future<String?> showPhotoSelectionDialog() async {
    // This will be implemented in the UI layer
    // Just a placeholder for the service structure
    return null;
  }

  // Validate image file
  bool validateImage(File imageFile) {
    try {
      // Check file size (max 5MB)
      final fileSizeInBytes = imageFile.lengthSync();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      
      if (fileSizeInMB > 5) {
        throw Exception('Image size should be less than 5MB');
      }

      // Check file extension
      final extension = imageFile.path.toLowerCase();
      if (!extension.endsWith('.jpg') && 
          !extension.endsWith('.jpeg') && 
          !extension.endsWith('.png')) {
        throw Exception('Only JPG, JPEG, and PNG files are allowed');
      }

      return true;
    } catch (e) {
      print('Image validation error: $e');
      return false;
    }
  }

  // Upload image to Cloudinary
Future<String?> uploadToCloudinary(File imageFile) async {
  try {
    final cloudName = 'drbt1cndv';
    final uploadPreset = 'unsigned_preset';

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(resBody);
      return data['secure_url']; // return hosted image URL
    } else {
      print('Cloudinary upload failed: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Upload error: $e');
    return null;
  }
}

}