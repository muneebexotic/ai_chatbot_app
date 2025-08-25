import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/photo_service.dart';
import '../services/cloudinary_service.dart';
import '../providers/auth_provider.dart';
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';
import 'chat_screen.dart';
import 'package:flutter_svg/flutter_svg.dart'; 

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final PhotoService _photoService = PhotoService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  File? _selectedImage;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Handle swipe back - same as skip button
          _skipPhotoUpload();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                AppColors.surface,
                AppColors.background,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            children: [
              // Custom App Bar
              SafeArea(
                bottom: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.9),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: const SizedBox(), // No back button for onboarding
                    title: AppText.bodyLarge(
                      'Profile Photo',
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    centerTitle: true,
                    actions: [
                      Padding(
                        padding: EdgeInsets.only(right: _getResponsivePadding(context)),
                        child: TextButton(
                          onPressed: _isUploading ? null : _skipPhotoUpload,
                          child: AppText.bodyMedium(
                            'Skip',
                            color: _isUploading 
                                ? AppColors.textTertiary 
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(_getResponsivePadding(context)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - _getResponsivePadding(context) * 2,
                          maxWidth: _getMaxContentWidth(context),
                        ),
                        child: Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: _getResponsiveSpacing(context, 20)),
                              
                              // Header Section
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(_getResponsivePadding(context) * 1.3),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(_getResponsiveBorderRadius(context)),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(_getResponsivePadding(context) * 0.67),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(_getResponsiveBorderRadius(context) * 0.67),
                                      ),
                                      child: Icon(
                                        Icons.person_add,
                                        size: _getResponsiveIconSize(context, 32),
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(height: _getResponsiveSpacing(context, 20)),
                                    AppText.displayMedium(
                                      'Add a Profile Photo',
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: _getResponsiveSpacing(context, 12)),
                                    AppText.bodyMedium(
                                      'Help others recognize you by adding a profile photo or generating a unique avatar',
                                      color: AppColors.textSecondary,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: _getResponsiveSpacing(context, 40)),
                              
                              // Photo Preview
                              _buildPhotoPreview(),
                              
                              SizedBox(height: _getResponsiveSpacing(context, 40)),
                              
                              // Photo Options
                              _buildPhotoOptions(),
                              
                              SizedBox(height: _getResponsiveSpacing(context, 40)),
                              
                              // Continue Button
                              _buildContinueButton(),
                              
                              SizedBox(height: _getResponsiveSpacing(context, 24)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    final photoSize = _getResponsivePhotoSize(context);
    return Container(
      width: photoSize,
      height: photoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: _getResponsiveBorderWidth(context),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: _selectedImage != null
            ? Image.file(
                _selectedImage!,
                width: photoSize,
                height: photoSize,
                fit: BoxFit.cover,
              )
            : _avatarUrl != null
                ? _buildAvatarWidget(photoSize)
                : Container(
                    color: AppColors.surface,
                    child: Icon(
                      Icons.person,
                      size: photoSize * 0.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
      ),
    );
  }

  Widget _buildAvatarWidget(double size) {
    // Check if the URL is an SVG (DiceBear returns SVG)
    if (_avatarUrl!.contains('.svg') || _avatarUrl!.contains('dicebear')) {
      return SvgPicture.network(
        _avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => Container(
          color: AppColors.surface,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    } else {
      // For regular images (PNG, JPG, etc.)
      return Image.network(
        _avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.surface,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.surface,
            child: Icon(
              Icons.error,
              size: size * 0.25,
              color: AppColors.textTertiary,
            ),
          );
        },
      );
    }
  }

  Widget _buildPhotoOptions() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_getResponsiveBorderRadius(context)),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOptionButton(
            icon: Icons.camera_alt_outlined,
            title: 'Take Photo',
            subtitle: 'Use camera to take a new photo',
            onTap: _isLoading ? null : _pickImageFromCamera,
            isFirst: true,
          ),
          _buildDivider(),
          _buildOptionButton(
            icon: Icons.photo_library_outlined,
            title: 'Choose from Gallery',
            subtitle: 'Select from your photo library',
            onTap: _isLoading ? null : _pickImageFromGallery,
          ),
          _buildDivider(),
          _buildOptionButton(
            icon: Icons.shuffle_outlined,
            title: 'Generate Avatar',
            subtitle: 'Get a unique AI-generated avatar',
            onTap: _isLoading ? null : _generateRandomAvatar,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: _getResponsivePadding(context) * 0.83),
      color: AppColors.primary.withOpacity(0.1),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? Radius.circular(_getResponsiveBorderRadius(context)) : Radius.zero,
          bottom: isLast ? Radius.circular(_getResponsiveBorderRadius(context)) : Radius.zero,
        ),
        child: Container(
          padding: EdgeInsets.all(_getResponsivePadding(context) * 0.83),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(_getResponsivePadding(context) * 0.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_getResponsiveBorderRadius(context) * 0.5),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: _getResponsiveIconSize(context, 24),
                ),
              ),
              SizedBox(width: _getResponsiveSpacing(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyLarge(
                      title,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    SizedBox(height: _getResponsiveSpacing(context, 4)),
                    AppText.bodySmall(
                      subtitle,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: _getResponsiveIconSize(context, 20),
                  height: _getResponsiveIconSize(context, 20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textTertiary,
                  size: _getResponsiveIconSize(context, 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final hasPhoto = _selectedImage != null || _avatarUrl != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasPhoto && !_isUploading ? _continueToChat : null,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: _getResponsiveButtonPadding(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_getResponsiveBorderRadius(context) * 0.67),
          ),
          backgroundColor: hasPhoto 
              ? AppColors.primary 
              : AppColors.textTertiary,
          elevation: hasPhoto ? 2 : 0,
          shadowColor: AppColors.primary.withOpacity(0.3),
        ),
        child: _isUploading
            ? SizedBox(
                height: _getResponsiveIconSize(context, 20),
                width: _getResponsiveIconSize(context, 20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
                ),
              )
            : AppText.bodyLarge(
                'Continue',
                color: hasPhoto ? AppColors.background : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
      ),
    );
  }

  // Responsive helper methods
  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) return 32.0; // Desktop/Large tablets
    if (screenWidth >= 600) return 28.0;  // Medium tablets
    return 24.0; // Mobile phones
  }

  double _getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth >= 1200 ? 1.2 : 
                       screenWidth >= 600 ? 1.1 : 1.0;
    return baseSpacing * scaleFactor;
  }

  double _getResponsiveBorderRadius(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) return 28.0;
    if (screenWidth >= 600) return 26.0;
    return 24.0;
  }

  double _getResponsivePhotoSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Base size calculation considering both width and height
    double baseSize = screenWidth * 0.4;
    
    // Clamp between reasonable limits
    if (screenWidth >= 1200) {
      baseSize = baseSize.clamp(180.0, 220.0);
    } else if (screenWidth >= 600) {
      baseSize = baseSize.clamp(160.0, 200.0);
    } else {
      baseSize = baseSize.clamp(140.0, 180.0);
    }
    
    // Ensure it doesn't take too much vertical space
    final maxVerticalSize = screenHeight * 0.25;
    return baseSize > maxVerticalSize ? maxVerticalSize : baseSize;
  }

  double _getResponsiveIconSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth >= 1200 ? 1.25 : 
                       screenWidth >= 600 ? 1.15 : 1.0;
    return baseSize * scaleFactor;
  }

  double _getResponsiveBorderWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= 600 ? 4.0 : 3.0;
  }

  double _getResponsiveButtonPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) return 22.0;
    if (screenWidth >= 600) return 20.0;
    return 18.0;
  }

  double _getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1200) return 600.0; // Desktop max width
    if (screenWidth >= 600) return screenWidth * 0.8; // Tablet
    return double.infinity; // Mobile full width
  }

  Future<void> _pickImageFromCamera() async {
    setState(() => _isLoading = true);
    try {
      final image = await _photoService.pickImageFromCamera();
      if (image != null && _photoService.validateImage(image)) {
        setState(() {
          _selectedImage = image;
          _avatarUrl = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error taking photo: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final image = await _photoService.pickImageFromGallery();
      if (image != null && _photoService.validateImage(image)) {
        setState(() {
          _selectedImage = image;
          _avatarUrl = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting photo: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateRandomAvatar() async {
    setState(() => _isLoading = true);
    try {
      final avatarUrl = await _photoService.generateRandomAvatar();
      setState(() {
        _avatarUrl = avatarUrl;
        _selectedImage = null;
      });
    } catch (e) {
      _showErrorSnackBar('Error generating avatar: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _continueToChat() async {
    setState(() => _isUploading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check if user is authenticated
      if (authProvider.currentUser?.uid == null || authProvider.currentUser!.uid.isEmpty) {
        throw Exception('❌ User is not authenticated.');
      }

      // Upload image or set avatar
      if (_selectedImage != null) {
        final imageUrl = await _cloudinaryService.uploadImage(_selectedImage!);
        if (imageUrl != null) {
          await authProvider.setUserAvatar(imageUrl);
        } else {
          throw Exception('❌ Cloudinary upload failed');
        }
      } else if (_avatarUrl != null) {
        await authProvider.setUserAvatar(_avatarUrl!);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _skipPhotoUpload() async {
    setState(() => _isUploading = true);
    try {
      final avatarUrl = await _photoService.generateRandomAvatar();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setUserAvatar(avatarUrl);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error creating avatar: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}