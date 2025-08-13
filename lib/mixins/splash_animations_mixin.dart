// Animation logic separation

import 'package:flutter/material.dart';
import '../constants/splash_constants.dart';

/// Mixin that provides animation setup and management for splash screen
mixin SplashAnimationsMixin on TickerProvider {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _subtitleAnimation;
  late final Animation<double> _loadingAnimation;

  /// Initialize all animations
  void initializeAnimations() {
    _setupAnimationController();
    _setupAnimations();
  }

  /// Setup the main animation controller
  void _setupAnimationController() {
    _animationController = AnimationController(
      duration: SplashConstants.animationDuration,
      vsync: this,
    );
  }

  /// Setup individual animations with proper curves and intervals
  void _setupAnimations() {
    _fadeAnimation = Tween<double>(
      begin: SplashConstants.fadeBegin,
      end: SplashConstants.fadeComplete,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          SplashConstants.fadeStart,
          SplashConstants.fadeEnd,
          curve: Curves.easeInOut,
        ),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: SplashConstants.scaleBegin,
      end: SplashConstants.scaleComplete,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          SplashConstants.scaleStart,
          SplashConstants.scaleEnd,
          curve: Curves.elasticOut,
        ),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          SplashConstants.slideStart,
          SplashConstants.slideEnd,
          curve: Curves.easeOut,
        ),
      ),
    );

    _subtitleAnimation = Tween<double>(
      begin: SplashConstants.fadeBegin,
      end: SplashConstants.subtitleOpacity,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          SplashConstants.subtitleStart,
          SplashConstants.subtitleEnd,
          curve: Curves.easeIn,
        ),
      ),
    );

    _loadingAnimation = Tween<double>(
      begin: SplashConstants.fadeBegin,
      end: SplashConstants.loadingOpacity,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          SplashConstants.loadingStart,
          SplashConstants.loadingEnd,
          curve: Curves.easeIn,
        ),
      ),
    );
  }

  /// Start the animation sequence
  void startAnimations() {
    _animationController.forward();
  }

  /// Dispose animation resources
  void disposeAnimations() {
    _animationController.dispose();
  }

  // Getters for accessing animations
  AnimationController get animationController => _animationController;
  Animation<double> get fadeAnimation => _fadeAnimation;
  Animation<double> get scaleAnimation => _scaleAnimation;
  Animation<Offset> get slideAnimation => _slideAnimation;
  Animation<double> get subtitleAnimation => _subtitleAnimation;
  Animation<double> get loadingAnimation => _loadingAnimation;
}