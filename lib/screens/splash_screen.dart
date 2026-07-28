import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/splash_controller.dart';
import '../components/ui/app_logo.dart';
import '../components/ui/app_text.dart';
import '../mixins/splash_animations_mixin.dart';
import '../constants/splash_constants.dart';
import '../utils/app_theme.dart';
import '../app/providers.dart';
import '../l10n/app_localizations.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
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
    final authProvider = ref.read(authNotifierProvider);
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
    return Consumer(
      builder: (context, ref, _) {
        final themeProvider = ref.watch(themeNotifierProvider);

        final isDark = themeProvider.isDark;
        
        return Scaffold(
          backgroundColor: AppColors.getBackground(isDark),
          body: Container(
            decoration: _buildGradientDecoration(isDark),
            child: SafeArea(
              child: _buildAnimatedContent(isDark),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _buildGradientDecoration(bool isDark) {
    if (isDark) {
      // Dark theme gradient
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0A0A), 
            Color(0xFF1A1A1A), 
            Color(0xFF0A0A0A)
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      );
    } else {
      // Light theme gradient
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFAFAFA), 
            Color(0xFFFFFFFF), 
            Color(0xFFF5F5F5)
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      );
    }
  }

  Widget _buildAnimatedContent(bool isDark) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAnimatedLogo(isDark),
              const SizedBox(height: SplashConstants.logoSpacing),
              _buildAnimatedTitle(isDark),
              const SizedBox(height: SplashConstants.subtitleSpacing),
              _buildAnimatedSubtitle(isDark),
              const SizedBox(height: SplashConstants.loadingSpacing),
              _buildLoadingIndicator(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo(bool isDark) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: AppLogo(
          size: AppLogoSize.large,
          showGlow: true,
          color: AppColors.getTextPrimary(isDark),
        ),
      ),
    );
  }

  Widget _buildAnimatedTitle(bool isDark) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: AppText.displayLarge(
          // TODO(muneeb): final app name (README, PRD §17.1). 'Kalaam' is the
          // working name and already the package id (com.muscodes.kalaam); the
          // old 'ChadGPT' here contradicted both on the first frame.
          AppLocalizations.of(context).appName,
          color: AppColors.getTextPrimary(isDark),
          textAlign: TextAlign.center,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAnimatedSubtitle(bool isDark) {
    return FadeTransition(
      opacity: subtitleAnimation,
      child: AppText.bodyMedium(
        // Was 'AI-Powered Conversations'. §7.6 bans "AI-powered" by name, and
        // it was the first copy a user ever read. This says what the product
        // does instead of what it is built from.
        AppLocalizations.of(context).splashTagline,
        color: AppColors.getTextSecondary(isDark),
        textAlign: TextAlign.center,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final controller = _controller;
          if (controller.hasError) {
            return _buildErrorIndicator(controller.error!, isDark);
          }
          
          return FadeTransition(
            opacity: loadingAnimation,
            child: SizedBox(
              width: SplashConstants.loadingIndicatorSize,
              height: SplashConstants.loadingIndicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: SplashConstants.loadingStrokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
                backgroundColor: AppColors.getTextTertiary(isDark).withValues(alpha: 0.2),
              ),
            ),
          );
        },
    );
  }

  Widget _buildErrorIndicator(String error, bool isDark) {
    return FadeTransition(
      opacity: loadingAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: SplashConstants.loadingIndicatorSize,
          ),
          const SizedBox(height: 8),
          AppText.bodySmall(
            'Initialization Error',
            color: AppColors.getTextTertiary(isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: AppText.caption(
              error,
              color: AppColors.getTextTertiary(isDark).withValues(alpha: 0.8),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}