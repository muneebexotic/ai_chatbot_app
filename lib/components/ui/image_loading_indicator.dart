import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../constants/image_generation_constants.dart';
import '../../utils/app_theme.dart';

class ImageLoadingIndicator extends StatefulWidget {
  final double progress;
  final String status;
  final bool showProgress;
  final bool showCancel;
  final VoidCallback? onCancel;
  final double size;

  const ImageLoadingIndicator({
    super.key,
    this.progress = 0.0,
    this.status = ImageGenerationMessages.generationStarted,
    this.showProgress = true,
    this.showCancel = true,
    this.onCancel,
    this.size = 200.0,
  });

  @override
  State<ImageLoadingIndicator> createState() => _ImageLoadingIndicatorState();
}

class _ImageLoadingIndicatorState extends State<ImageLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    // Rotation animation for the outer ring
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Pulse animation for the center icon
    _pulseController = AnimationController(
      duration: ImageGenerationConstants.pulseAnimationDuration,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Wave animation for the background
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));
  }

  void _startAnimations() {
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading visualization
          Expanded(
            flex: 3,
            child: Center(
              child: SizedBox(
                width: widget.size * 0.6,
                height: widget.size * 0.6,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background wave effect
                    AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(widget.size * 0.6, widget.size * 0.6),
                          painter: WavePainter(
                            progress: _waveAnimation.value,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        );
                      },
                    ),

                    // Outer rotating ring
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value,
                          child: CustomPaint(
                            size: Size(widget.size * 0.5, widget.size * 0.5),
                            painter: LoadingRingPainter(
                              progress: widget.showProgress ? widget.progress : 1.0,
                              color: AppColors.primary,
                              backgroundColor: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                        );
                      },
                    ),

                    // Center pulsing icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              size: widget.size * 0.15,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),

                    // Progress overlay
                    if (widget.showProgress && widget.progress > 0)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(widget.progress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Status text
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.status,
                    style: TextStyle(
                      color: AppColors.getTextPrimary(isDark),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  if (widget.showProgress && widget.progress > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: widget.progress,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Cancel button
          if (widget.showCancel && widget.onCancel != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.getTextSecondary(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LoadingRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  LoadingRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 4.0;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );

    // Add rotating dots for visual interest
    for (int i = 0; i < 3; i++) {
      final angle = (2 * math.pi / 3) * i + (progress * 2 * math.pi);
      final dotCenter = Offset(
        center.dx + (radius - 8) * math.cos(angle),
        center.dy + (radius - 8) * math.sin(angle),
      );

      final dotPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(dotCenter, 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(LoadingRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class WavePainter extends CustomPainter {
  final double progress;
  final Color color;

  WavePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i * 0.3) % 1.0;
      final radius = maxRadius * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.5;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Compact version for smaller spaces
class CompactImageLoadingIndicator extends StatefulWidget {
  final double progress;
  final String status;
  final double size;

  const CompactImageLoadingIndicator({
    super.key,
    this.progress = 0.0,
    this.status = 'Generating...',
    this.size = 80.0,
  });

  @override
  State<CompactImageLoadingIndicator> createState() =>
      _CompactImageLoadingIndicatorState();
}

class _CompactImageLoadingIndicatorState extends State<CompactImageLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating progress indicator
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animation.value,
                child: CircularProgressIndicator(
                  value: widget.progress > 0 ? widget.progress : null,
                  strokeWidth: 3,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                ),
              );
            },
          ),

          // Center icon
          Icon(
            Icons.image,
            color: AppColors.primary,
            size: widget.size * 0.3,
          ),

          // Progress text
          if (widget.progress > 0)
            Positioned(
              bottom: 4,
              child: Text(
                '${(widget.progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }
}