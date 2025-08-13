import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../controllers/splash_controller.dart';
import '../components/ui/app_logo.dart';
import '../components/ui/app_text.dart';
import '../mixins/splash_animations_mixin.dart';
import '../constants/splash_constants.dart';
import '../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, SplashAnimationsMixin {
  
  late final SplashController _controller;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    // Initialize animations
    initializeAnimations();
    
    // Setup controller
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _controller = SplashController(
      authProvider: authProvider,
      onNavigationComplete: _onNavigationComplete,
    );

    // Start initialization sequence
    _startInitializationSequence();
  }

  void _startInitializationSequence() {
    // Start animations
    startAnimations();
    
    // Initialize app after a brief delay to show animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.initialize(context);
    });
  }

  void _onNavigationComplete() {
    // Callback for when navigation is complete
    // Could be used for cleanup or analytics
  }

  @override
  void dispose() {
    disposeAnimations();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _buildAnimatedContent(),
        ),
      ),
    );
  }

  Widget _buildAnimatedContent() {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAnimatedLogo(),
              const SizedBox(height: SplashConstants.logoSpacing),
              _buildAnimatedTitle(),
              const SizedBox(height: SplashConstants.subtitleSpacing),
              _buildAnimatedSubtitle(),
              const SizedBox(height: SplashConstants.loadingSpacing),
              _buildLoadingIndicator(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: const AppLogo(
          size: AppLogoSize.large,
          showGlow: true,
        ),
      ),
    );
  }

  Widget _buildAnimatedTitle() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: const AppText.displayLarge(
          'ChadGPT',
          color: Colors.white,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAnimatedSubtitle() {
    return FadeTransition(
      opacity: subtitleAnimation,
      child: const AppText.bodyMedium(
        'AI-Powered Conversations',
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<SplashController>(
        builder: (context, controller, child) {
          if (controller.hasError) {
            return _buildErrorIndicator(controller.error!);
          }
          
          return FadeTransition(
            opacity: loadingAnimation,
            child: const SizedBox(
              width: SplashConstants.loadingIndicatorSize,
              height: SplashConstants.loadingIndicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: SplashConstants.loadingStrokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textTertiary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorIndicator(String error) {
    return FadeTransition(
      opacity: loadingAnimation,
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.textTertiary,
            size: SplashConstants.loadingIndicatorSize,
          ),
          const SizedBox(height: 8),
          AppText.bodySmall(
            'Initialization Error',
            color: AppColors.textTertiary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}