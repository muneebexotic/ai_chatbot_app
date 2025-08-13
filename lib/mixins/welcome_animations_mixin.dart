import 'package:flutter/material.dart';
import '../constants/welcome_screen_constants.dart';

mixin WelcomeAnimationsMixin<T extends StatefulWidget> on State<T>, TickerProvider {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<Offset> _buttonsSlideAnimation;

  AnimationController get animationController => _animationController;
  Animation<double> get fadeAnimation => _fadeAnimation;
  Animation<double> get subtitleFadeAnimation => _subtitleFadeAnimation;
  Animation<Offset> get slideAnimation => _slideAnimation;
  Animation<Offset> get titleSlideAnimation => _titleSlideAnimation;
  Animation<Offset> get buttonsSlideAnimation => _buttonsSlideAnimation;

  void initializeWelcomeAnimations() {
    _animationController = AnimationController(
      duration: WelcomeScreenConstants.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: WelcomeScreenConstants.fadeStart,
      end: WelcomeScreenConstants.fadeEnd,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: WelcomeScreenConstants.fadeInterval,
      ),
    );

    _subtitleFadeAnimation = Tween<double>(
      begin: WelcomeScreenConstants.fadeStart,
      end: WelcomeScreenConstants.subtitleOpacity,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: WelcomeScreenConstants.subtitleInterval,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: WelcomeScreenConstants.initialSlideOffset,
      end: WelcomeScreenConstants.zeroOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: WelcomeScreenConstants.slideInterval,
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: WelcomeScreenConstants.titleSlideOffset,
      end: WelcomeScreenConstants.zeroOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: WelcomeScreenConstants.titleInterval,
      ),
    );

    _buttonsSlideAnimation = Tween<Offset>(
      begin: WelcomeScreenConstants.buttonsSlideOffset,
      end: WelcomeScreenConstants.zeroOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: WelcomeScreenConstants.buttonsInterval,
      ),
    );
  }

  void startWelcomeAnimations() {
    _animationController.forward();
  }

  void disposeWelcomeAnimations() {
    _animationController.dispose();
  }

  void resetWelcomeAnimations() {
    _animationController.reset();
  }
}