import 'package:flutter/material.dart';
import '../constants/signup_constants.dart';

/// Mixin for managing SignUp screen animations with performance optimizations
/// 
/// Features:
/// - Centralized animation management
/// - Optimized animation curves and timings
/// - Memory leak prevention
/// - Staggered entrance animations
/// - Reusable animation patterns
mixin SignUpAnimationsMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  
  // Animation controller
  late AnimationController _animationController;

  // Main animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Input field animations (staggered)
  late Animation<Offset> _inputAnimation1;
  late Animation<Offset> _inputAnimation2;
  late Animation<Offset> _inputAnimation3;
  late Animation<Offset> _buttonAnimation;

  // Animation getters
  AnimationController get animationController => _animationController;
  Animation<double> get fadeAnimation => _fadeAnimation;
  Animation<Offset> get slideAnimation => _slideAnimation;
  Animation<Offset> get inputAnimation1 => _inputAnimation1;
  Animation<Offset> get inputAnimation2 => _inputAnimation2;
  Animation<Offset> get inputAnimation3 => _inputAnimation3;
  Animation<Offset> get buttonAnimation => _buttonAnimation;

  /// Initialize all animations
  void initializeAnimations() {
    _createAnimationController();
    _createMainAnimations();
    _createStaggeredAnimations();
  }

  /// Start animations
  void startAnimations() {
    _animationController.forward();
  }

  /// Dispose animations to prevent memory leaks
  void disposeAnimations() {
    _animationController.dispose();
  }

  /// Create the main animation controller
  void _createAnimationController() {
    _animationController = AnimationController(
      duration: SignUpConstants.mainAnimationDuration,
      vsync: this,
    );
  }

  /// Create main fade and slide animations
  void _createMainAnimations() {
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.0,
          0.8,
          curve: Curves.easeOut,
        ),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.2,
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  /// Create staggered animations for inputs and button
  void _createStaggeredAnimations() {
    // First input field
    _inputAnimation1 = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.3,
          0.8,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Second input field
    _inputAnimation2 = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.4,
          0.9,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Third input field
    _inputAnimation3 = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.5,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Button animation
    _buttonAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.6,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  /// Reset animations (useful for testing or state changes)
  void resetAnimations() {
    _animationController.reset();
  }

  /// Reverse animations (useful for navigation transitions)
  void reverseAnimations() {
    _animationController.reverse();
  }

  /// Check if animations are complete
  bool get animationsComplete => _animationController.isCompleted;

  /// Get current animation progress (0.0 to 1.0)
  double get animationProgress => _animationController.value;
}