import 'package:flutter/material.dart';
import '../constants/login_constants.dart';

/// Mixin to handle login screen animations
mixin LoginAnimationsMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _emailSlideAnimation;
  late Animation<Offset> _passwordSlideAnimation;
  late Animation<Offset> _buttonSlideAnimation;

  AnimationController get animationController => _animationController;
  Animation<double> get fadeAnimation => _fadeAnimation;
  Animation<Offset> get slideAnimation => _slideAnimation;
  Animation<Offset> get emailSlideAnimation => _emailSlideAnimation;
  Animation<Offset> get passwordSlideAnimation => _passwordSlideAnimation;
  Animation<Offset> get buttonSlideAnimation => _buttonSlideAnimation;

  void initializeLoginAnimations() {
    _animationController = AnimationController(
      duration: LoginConstants.animationDuration,
      vsync: this,
    );

    // Fade animation for overall opacity
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          LoginConstants.fadeStartInterval,
          LoginConstants.fadeEndInterval,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Main slide animation for title
    _slideAnimation = Tween<Offset>(
      begin: LoginConstants.initialSlideOffset,
      end: LoginConstants.finalSlideOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          LoginConstants.slideStartInterval,
          LoginConstants.slideEndInterval,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // Email input slide animation
    _emailSlideAnimation = Tween<Offset>(
      begin: LoginConstants.inputSlideOffset,
      end: LoginConstants.finalSlideOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          LoginConstants.emailAnimationStart,
          LoginConstants.slideEndInterval,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Password input slide animation
    _passwordSlideAnimation = Tween<Offset>(
      begin: LoginConstants.inputSlideOffset,
      end: LoginConstants.finalSlideOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          LoginConstants.passwordAnimationStart,
          LoginConstants.slideEndInterval,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Button slide animation
    _buttonSlideAnimation = Tween<Offset>(
      begin: LoginConstants.inputSlideOffset,
      end: LoginConstants.finalSlideOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          LoginConstants.buttonAnimationStart,
          LoginConstants.slideEndInterval,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  void startLoginAnimations() {
    _animationController.forward();
  }

  void disposeLoginAnimations() {
    _animationController.dispose();
  }
}