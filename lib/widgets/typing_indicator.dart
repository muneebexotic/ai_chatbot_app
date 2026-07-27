import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_theme.dart';
import 'dart:math' as math;
import '../app/providers.dart';

// Main modern typing indicator with sophisticated animations
class ModernTypingIndicator extends ConsumerStatefulWidget {
  final String? customText;
  final bool showAvatar;
  final Widget? customAvatar;
  
  const ModernTypingIndicator({
    super.key,
    this.customText,
    this.showAvatar = false,
    this.customAvatar,
  });

  @override
  ConsumerState<ModernTypingIndicator> createState() => _ModernTypingIndicatorState();
}

class _ModernTypingIndicatorState extends ConsumerState<ModernTypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _dotsController;
  late AnimationController _shimmerController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Fade in animation for the entire component
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Dots animation controller
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    
    // Shimmer effect controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _dotsController.repeat();
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dotsController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _buildBotAvatar(bool isDark) {
    if (widget.customAvatar != null) {
      return widget.customAvatar!;
    }
    
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.getSurface(isDark),
            AppColors.getSurfaceVariant(isDark),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/bot_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 14,
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _dotsController,
          builder: (context, child) {
            final delay = index * 0.2;
            double animValue = (_dotsController.value + delay) % 1.0;
            
            // Create a smooth wave effect
            double scale = 0.6 + (0.4 * (1 + math.sin(animValue * 2 * math.pi)) / 2);
            double opacity = 0.4 + (0.6 * (1 + math.sin(animValue * 2 * math.pi)) / 2);
            
            return Container(
              margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: opacity),
                        AppColors.secondary.withValues(alpha: opacity * 0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3 * opacity),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildShimmeredText(bool isDark) {
    final text = widget.customText ?? 'AI is thinking...';
    
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.getTextTertiary(isDark),
                AppColors.getTextSecondary(isDark),
                AppColors.getTextPrimary(isDark),
                AppColors.getTextSecondary(isDark),
                AppColors.getTextTertiary(isDark),
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              transform: GradientRotation(_shimmerAnimation.value * 3.14159),
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'GeneralSans',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.getTextPrimary(isDark),
              letterSpacing: 0.2,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final themeProvider = ref.watch(themeNotifierProvider);

        final isDark = themeProvider.isDark;
        
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            margin: const EdgeInsets.only(right: 48, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showAvatar) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    child: _buildBotAvatar(isDark),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.getSurface(isDark),
                          AppColors.getSurfaceVariant(isDark).withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: widget.showAvatar ? const Radius.circular(6) : const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: const Radius.circular(20),
                        bottomRight: const Radius.circular(20),
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAnimatedDots(),
                        const SizedBox(width: 12),
                        _buildShimmeredText(isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Wave-based typing indicator with modern aesthetics
class WaveTypingIndicator extends ConsumerStatefulWidget {
  final String? customText;
  final Color? primaryColor;
  final bool showAvatar;
  
  const WaveTypingIndicator({
    super.key,
    this.customText,
    this.primaryColor,
    this.showAvatar = true,
  });

  @override
  ConsumerState<WaveTypingIndicator> createState() => _WaveTypingIndicatorState();
}

class _WaveTypingIndicatorState extends ConsumerState<WaveTypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _containerController;
  late List<Animation<double>> _animations;
  late Animation<double> _containerAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    
    _containerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _containerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _containerController,
      curve: Curves.easeOut,
    ));

    _animations = List.generate(5, (index) {
      return Tween<double>(begin: 0.3, end: 1.2).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.1,
            0.8 + (index * 0.05),
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    _containerController.forward();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _containerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final themeProvider = ref.watch(themeNotifierProvider);

        final isDark = themeProvider.isDark;
        final primaryColor = widget.primaryColor ?? AppColors.primary;
        
        return FadeTransition(
          opacity: _containerAnimation,
          child: Container(
            margin: const EdgeInsets.only(right: 48, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showAvatar) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.getSurface(isDark),
                          AppColors.getSurfaceVariant(isDark),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: primaryColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.only(
                        topLeft: widget.showAvatar ? const Radius.circular(6) : const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: const Radius.circular(20),
                        bottomRight: const Radius.circular(20),
                      ),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Wave bars
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(5, (index) {
                            return AnimatedBuilder(
                              animation: _animations[index],
                              builder: (context, child) {
                                return Container(
                                  margin: EdgeInsets.only(right: index < 4 ? 3 : 0),
                                  width: 3,
                                  height: 4 + (_animations[index].value * 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        primaryColor,
                                        primaryColor.withValues(alpha: 0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 2,
                                        spreadRadius: 0.5,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          widget.customText ?? 'Processing...',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: AppColors.getTextSecondary(isDark),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Pulse typing indicator with breathing effect
class PulseTypingIndicator extends ConsumerStatefulWidget {
  final String? customText;
  final bool showAvatar;
  
  const PulseTypingIndicator({
    super.key,
    this.customText,
    this.showAvatar = true,
  });

  @override
  ConsumerState<PulseTypingIndicator> createState() => _PulseTypingIndicatorState();
}

class _PulseTypingIndicatorState extends ConsumerState<PulseTypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final themeProvider = ref.watch(themeNotifierProvider);

        final isDark = themeProvider.isDark;
        
        return Container(
          margin: const EdgeInsets.only(right: 48, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showAvatar) ...[
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.getSurface(isDark),
                              AppColors.getSurfaceVariant(isDark),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3 + (_glowAnimation.value * 0.4)),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: _glowAnimation.value * 0.4),
                              blurRadius: 8 + (_glowAnimation.value * 8),
                              spreadRadius: _glowAnimation.value * 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 14,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(isDark),
                          borderRadius: BorderRadius.only(
                            topLeft: widget.showAvatar ? const Radius.circular(6) : const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: const Radius.circular(20),
                            bottomRight: const Radius.circular(20),
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: 0.7 + (_glowAnimation.value * 0.3),
                              child: Text(
                                widget.customText ?? 'AI is generating response...',
                                style: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                  color: AppColors.getTextSecondary(isDark),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}