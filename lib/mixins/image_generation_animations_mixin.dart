import 'package:flutter/material.dart';

/// Mixin providing animation controllers and common animation patterns for image generation UI
mixin ImageGenerationAnimationsMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  // Animation states
  bool _isAnimating = false;
  bool get isAnimating => _isAnimating;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Fade animation for dialog appearance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Slide animation for content appearance
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Scale animation for buttons and interactive elements
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation for loading indicators
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Progress animation for generation progress
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));

    // Pulse animation for loading states
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Shimmer animation for loading placeholders
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    ));
  }

  // Animation control methods

  /// Start entrance animations (fade + slide)
  Future<void> startEntranceAnimation() async {
    _isAnimating = true;
    await Future.wait([
      _fadeController.forward(),
      _slideController.forward(),
    ]);
    _isAnimating = false;
  }

  /// Start exit animations
  Future<void> startExitAnimation() async {
    _isAnimating = true;
    await Future.wait([
      _fadeController.reverse(),
      _slideController.reverse(),
    ]);
    _isAnimating = false;
  }

  /// Animate button press
  Future<void> animateButtonPress() async {
    await _scaleController.forward();
    await _scaleController.reverse();
  }

  /// Start loading animation
  void startLoadingAnimation() {
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  /// Stop loading animation
  void stopLoadingAnimation() {
    _rotationController.stop();
    _rotationController.reset();
    _pulseController.stop();
    _pulseController.reset();
  }

  /// Animate progress update
  Future<void> animateProgress(double progress) async {
    await _progressController.animateTo(progress);
  }

  /// Reset progress animation
  void resetProgress() {
    _progressController.reset();
  }

  /// Start shimmer loading effect
  void startShimmerAnimation() {
    _shimmerController.repeat();
  }

  /// Stop shimmer loading effect
  void stopShimmerAnimation() {
    _shimmerController.stop();
    _shimmerController.reset();
  }

  /// Animate success state (scale up briefly)
  Future<void> animateSuccess() async {
    await _scaleController.animateTo(1.1);
    await _scaleController.animateTo(1.0);
  }

  /// Animate error state (shake effect)
  Future<void> animateError() async {
    const double shakeDistance = 10.0;
    const int shakeCount = 3;
    
    for (int i = 0; i < shakeCount; i++) {
      await _slideController.animateTo(shakeDistance / 100);
      await _slideController.animateTo(-shakeDistance / 100);
    }
    await _slideController.animateTo(0.0);
  }

  // Widget builders for animated components

  /// Build fade transition wrapper
  Widget buildFadeTransition({required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: child,
    );
  }

  /// Build slide transition wrapper
  Widget buildSlideTransition({required Widget child}) {
    return SlideTransition(
      position: _slideAnimation,
      child: child,
    );
  }

  /// Build scale transition wrapper
  Widget buildScaleTransition({required Widget child}) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: child,
    );
  }

  /// Build combined entrance animation wrapper
  Widget buildEntranceAnimation({required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: child,
      ),
    );
  }

  /// Build rotating loading indicator
  Widget buildRotatingLoader({
    required Widget child,
    bool isLoading = false,
  }) {
    if (!isLoading) return child;
    
    return RotationTransition(
      turns: _rotationAnimation,
      child: child,
    );
  }

  /// Build pulsing loading indicator
  Widget buildPulsingLoader({
    required Widget child,
    bool isLoading = false,
  }) {
    if (!isLoading) return child;
    
    return ScaleTransition(
      scale: _pulseAnimation,
      child: FadeTransition(
        opacity: _pulseAnimation,
        child: child,
      ),
    );
  }

  /// Build progress indicator with animation
  Widget buildAnimatedProgress({
    required double value,
    Color? color,
    Color? backgroundColor,
    double height = 4.0,
  }) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: value * _progressAnimation.value,
          color: color ?? Theme.of(context).primaryColor,
          backgroundColor: backgroundColor ?? Colors.grey.withOpacity(0.2),
          minHeight: height,
        );
      },
    );
  }

  /// Build shimmer loading effect
  Widget buildShimmerEffect({
    required Widget child,
    bool isLoading = false,
    Color? baseColor,
    Color? highlightColor,
  }) {
    if (!isLoading) return child;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final effectiveBaseColor = baseColor ?? 
        (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final effectiveHighlightColor = highlightColor ?? 
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                effectiveBaseColor,
                effectiveHighlightColor,
                effectiveBaseColor,
              ],
              stops: [
                0.0,
                0.5,
                1.0,
              ],
              transform: GradientRotation(_shimmerAnimation.value * 3.14159),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }

  /// Build staggered list animation
  Widget buildStaggeredAnimation({
    required List<Widget> children,
    int animationDelay = 100,
  }) {
    return Column(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        
        return AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, _) {
            final delay = index * animationDelay / 1000.0;
            final adjustedValue = (_fadeAnimation.value - delay).clamp(0.0, 1.0);
            
            return FadeTransition(
              opacity: AlwaysStoppedAnimation(adjustedValue),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(AlwaysStoppedAnimation(adjustedValue)),
                child: child,
              ),
            );
          },
        );
      }).toList(),
    );
  }

  /// Build bouncing button animation
  Widget buildBouncingButton({
    required Widget child,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        _scaleController.forward();
      },
      onTapUp: (_) {
        _scaleController.reverse();
        onPressed?.call();
      },
      onTapCancel: () {
        _scaleController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: child,
      ),
    );
  }

  /// Build morphing container animation
  Widget buildMorphingContainer({
    required Widget child,
    required bool expanded,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      height: expanded ? null : 0,
      child: AnimatedOpacity(
        duration: duration,
        opacity: expanded ? 1.0 : 0.0,
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // Animation getters for external access
  Animation<double> get fadeAnimation => _fadeAnimation;
  Animation<Offset> get slideAnimation => _slideAnimation;
  Animation<double> get scaleAnimation => _scaleAnimation;
  Animation<double> get rotationAnimation => _rotationAnimation;
  Animation<double> get progressAnimation => _progressAnimation;
  Animation<double> get pulseAnimation => _pulseAnimation;
  Animation<double> get shimmerAnimation => _shimmerAnimation;

  // Controller getters
  AnimationController get fadeController => _fadeController;
  AnimationController get slideController => _slideController;
  AnimationController get scaleController => _scaleController;
  AnimationController get rotationController => _rotationController;
  AnimationController get progressController => _progressController;
  AnimationController get pulseController => _pulseController;
  AnimationController get shimmerController => _shimmerController;
}