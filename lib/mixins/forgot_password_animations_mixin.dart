import 'package:flutter/material.dart';

mixin ForgotPasswordAnimationsMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late AnimationController animationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  void initAnimations() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }
}
