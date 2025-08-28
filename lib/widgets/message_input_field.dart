import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/themes_provider.dart';
import '../screens/subscription_screen.dart';
import '../components/ui/app_text.dart';

class MessageInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final VoidCallback onMicTap;
  final VoidCallback onSend;
  final Function(String)? onTextChanged;
  final Function(bool)? onTypingStatusChanged;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.onMicTap,
    required this.onSend,
    this.onTextChanged,
    this.onTypingStatusChanged,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField>
    with TickerProviderStateMixin {
  AnimationController? _micAnimationController;
  AnimationController? _sendAnimationController;
  AnimationController? _expandAnimationController;
  AnimationController? _focusAnimationController;
  Animation<double>? _micPulseAnimation;
  Animation<double>? _sendScaleAnimation;
  Animation<double>? _expandAnimation;
  Animation<double>? _focusAnimation;
  
  bool _isFocused = false;
  bool _hasText = false;
  bool _isTyping = false;
  double _inputHeight = 56.0; // Initial height
  
  // Height constraints
  static const double _minHeight = 56.0;
  static const double _maxHeight = 120.0; // About 4-5 lines
  static const double _lineHeight = 22.0; // Approximate line height
  
  Timer? _typingTimer;
  static const Duration _typingTimeout = Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupListeners();
  }

  void _initializeAnimations() {
    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _sendAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _expandAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _micPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _micAnimationController!,
      curve: Curves.easeInOut,
    ));

    _sendScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _sendAnimationController!,
      curve: Curves.easeInOut,
    ));

    _expandAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _expandAnimationController!,
      curve: Curves.easeOutCubic,
    ));

    _focusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _focusAnimationController!,
      curve: Curves.easeOutCubic,
    ));
  }

  void _setupListeners() {
    widget.focusNode.addListener(() {
      final wasFocused = _isFocused;
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
      
      if (_isFocused && !wasFocused) {
        _focusAnimationController?.forward();
      } else if (!_isFocused && wasFocused) {
        _focusAnimationController?.reverse();
        _stopTyping();
      }
    });

    widget.controller.addListener(_onTextChanged);

    if (widget.isListening) {
      _micAnimationController?.repeat(reverse: true);
    }
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    final text = widget.controller.text.trim();
    
    // Calculate new height based on text content
    _calculateInputHeight();
    
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
      if (hasText) {
        _expandAnimationController?.forward();
      } else {
        _expandAnimationController?.reverse();
        _stopTyping();
      }
    }

    widget.onTextChanged?.call(widget.controller.text);

    if (text.isNotEmpty && _isFocused) {
      if (!_isTyping) {
        _startTyping();
      }
      _resetTypingTimer();
    } else {
      _stopTyping();
    }
  }

  void _calculateInputHeight() {
    if (widget.controller.text.isEmpty) {
      setState(() {
        _inputHeight = _minHeight;
      });
      return;
    }

    // Create a text painter to measure the text
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.controller.text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    // Calculate the width available for text (reduced width minus padding and icons)
    final availableWidth = MediaQuery.of(context).size.width - 
        200; // Increased space deduction for narrower input field

    textPainter.layout(maxWidth: availableWidth);
    
    // Calculate required height with padding
    final textHeight = textPainter.height;
    final paddingHeight = 32.0; // Top and bottom padding (16 * 2)
    final newHeight = (textHeight + paddingHeight).clamp(_minHeight, _maxHeight);
    
    if (newHeight != _inputHeight) {
      setState(() {
        _inputHeight = newHeight;
      });
    }

    textPainter.dispose();
  }

  void _startTyping() {
    setState(() {
      _isTyping = true;
    });
    widget.onTypingStatusChanged?.call(true);
    _resetTypingTimer();
  }

  void _resetTypingTimer() {
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimeout, _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      setState(() {
        _isTyping = false;
      });
      widget.onTypingStatusChanged?.call(false);
      _typingTimer?.cancel();
    }
  }

  @override
  void didUpdateWidget(MessageInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isListening && !oldWidget.isListening) {
      _micAnimationController?.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _micAnimationController?.stop();
      _micAnimationController?.reset();
    }
  }

  @override
  void dispose() {
    _micAnimationController?.dispose();
    _sendAnimationController?.dispose();
    _expandAnimationController?.dispose();
    _focusAnimationController?.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSendTap() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canSend = await authProvider.canSendMessage();
    
    if (!canSend) {
      _showUsageLimitDialog('message');
      return;
    }

    _stopTyping();
    
    _sendAnimationController?.forward().then((_) {
      _sendAnimationController?.reverse();
      widget.onSend();
      // Reset height after sending
      setState(() {
        _inputHeight = _minHeight;
      });
    });
  }

  Future<void> _handleMicTap() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canSendVoice = await authProvider.canSendVoice();
    
    if (!canSendVoice) {
      _showUsageLimitDialog('voice');
      return;
    }

    widget.onMicTap();
  }

  Future<void> _handleImageUpload() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canUpload = await authProvider.canUploadImage();
    
    if (!canUpload) {
      _showUsageLimitDialog('image');
      return;
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Image upload coming soon!',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.getSurface(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showUsageLimitDialog(String limitType) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText.titleLarge(
                  'Daily Limit Reached',
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.bodyMedium(
                'You\'ve reached your daily $limitType limit for free users.',
                color: AppColors.getTextSecondary(isDark),
              ),
              const SizedBox(height: 8),
              AppText.bodySmall(
                authProvider.usageText,
                color: AppColors.getTextTertiary(isDark),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyMedium(
                      'Upgrade to Premium for:',
                      color: AppColors.getTextPrimary(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                    AppText.bodySmall(
                      '• Unlimited messages\n• All personas\n• Unlimited images & voice\n• Priority support',
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: AppText.bodyMedium(
                'Later',
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: AppText.bodyMedium(
                'Upgrade',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, authProvider, themeProvider, child) {
        final isDark = themeProvider.isDark;
        
        return Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), // Increased horizontal padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // Center align everything
              children: [
                // Main input container with reduced width
                Flexible(
                  flex: 6, // Reduced flex to make input narrower
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _focusAnimation ?? AlwaysStoppedAnimation(0.0),
                    ]),
                    builder: (context, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        height: _inputHeight,
                        constraints: BoxConstraints(
                          minHeight: _minHeight,
                          maxHeight: _maxHeight,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.getSurface(isDark), 
                              AppColors.getSurfaceVariant(isDark)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: _isFocused
                                ? AppColors.primary.withOpacity(0.5)
                                : AppColors.getTextPrimary(isDark).withOpacity(0.08),
                            width: _isFocused ? 2 : 1,
                          ),
                          boxShadow: _isFocused
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center, // Center align content
                          children: [
                            // Text input field
                            Expanded(
                              child: TextField(
                                cursorColor: AppColors.primary,
                                controller: widget.controller,
                                focusNode: widget.focusNode,
                                enabled: authProvider.isPremium || authProvider.paymentService.remainingMessages > 0,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  color: AppColors.getTextPrimary(isDark),
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: authProvider.isPremium || authProvider.paymentService.remainingMessages > 0 
                                      ? 'Type your message...'
                                      : 'Daily message limit reached',
                                  filled: false,
                                  hintStyle: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                    fontSize: 16,
                                    color: AppColors.getTextTertiary(isDark),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide.none,
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  isDense: false,
                                ),
                                onSubmitted: (_) => _handleSendTap(),
                                textCapitalization: TextCapitalization.sentences,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                maxLines: null,
                                minLines: 1,
                                autocorrect: true,
                                enableSuggestions: true,
                                onChanged: (_) {},
                              ),
                            ),
                            
                            // Icons inside the input field - larger size
                            AnimatedBuilder(
                              animation: _expandAnimation ?? AlwaysStoppedAnimation(0.0),
                              builder: (context, child) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4.0), // Small right padding
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_hasText) ...[
                                        _buildIconButton(
                                          icon: Icons.attach_file_rounded,
                                          onPressed: _handleImageUpload,
                                          tooltip: 'Attach file',
                                          isDark: isDark,
                                        ),
                                        _buildIconButton(
                                          icon: Icons.camera_alt_rounded,
                                          onPressed: _handleImageUpload,
                                          tooltip: 'Take photo',
                                          isDark: isDark,
                                        ),
                                      ],
                                      if (_hasText) ...[
                                        Transform.scale(
                                          scale: _expandAnimation?.value ?? 0.0,
                                          child: Opacity(
                                            opacity: _expandAnimation?.value ?? 0.0,
                                            child: _buildIconButton(
                                              icon: Icons.attach_file_rounded,
                                              onPressed: _handleImageUpload,
                                              tooltip: 'Attach file',
                                              isDark: isDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 12), // Slightly increased spacing
                
                // Voice/Send button (larger size, center aligned)
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _micPulseAnimation ?? AlwaysStoppedAnimation(1.0),
                    _sendScaleAnimation ?? AlwaysStoppedAnimation(1.0),
                  ]),
                  builder: (context, child) {
                    final micAnimationValue = _micPulseAnimation?.value ?? 1.0;
                    final sendAnimationValue = _sendScaleAnimation?.value ?? 1.0;
                    
                    final canSendMessage = authProvider.isPremium || authProvider.paymentService.remainingMessages > 0;
                    final canSendVoice = authProvider.isPremium || authProvider.paymentService.remainingVoice > 0;
                    final isEnabled = _hasText ? canSendMessage : canSendVoice;
                    
                    return Transform.scale(
                      scale: _hasText 
                          ? sendAnimationValue 
                          : (widget.isListening ? micAnimationValue : 1.0),
                      child: Container(
                        width: 55, // Slightly larger button
                        height: 55, // Slightly larger button
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _hasText || widget.isListening
                                ? (isEnabled 
                                    ? [AppColors.primary, AppColors.secondary]
                                    : [AppColors.getTextTertiary(isDark).withOpacity(0.5), AppColors.getTextTertiary(isDark).withOpacity(0.3)])
                                : [AppColors.getSurface(isDark), AppColors.getSurfaceVariant(isDark)],
                          ),
                          shape: BoxShape.circle,
                          border: !_hasText && !widget.isListening
                              ? Border.all(
                                  color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
                                  width: 1,
                                )
                              : null,
                          boxShadow: (_hasText || widget.isListening) && isEnabled
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: IconButton(
                          onPressed: isEnabled 
                              ? (_hasText ? _handleSendTap : _handleMicTap)
                              : null,
                          icon: Icon(
                            _hasText 
                                ? Icons.send_rounded
                                : (widget.isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                            color: isEnabled
                                ? (_hasText || widget.isListening
                                    ? Colors.white
                                    : AppColors.getTextSecondary(isDark))
                                : AppColors.getTextTertiary(isDark).withOpacity(0.5),
                            size: 26, // Larger icon
                          ),
                          tooltip: _hasText 
                              ? (canSendMessage ? 'Send message' : 'Daily message limit reached')
                              : (widget.isListening 
                                  ? 'Stop recording' 
                                  : (canSendVoice ? 'Start recording' : 'Daily voice limit reached')),
                          splashRadius: 28,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required bool isDark,
  }) {
    return Container(
      width: 44, // Larger container
      height: 44, // Larger container
      margin: const EdgeInsets.symmetric(horizontal: 2), // Small margin between icons
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppColors.getTextSecondary(isDark),
        tooltip: tooltip,
        splashRadius: 20,
        iconSize: 26, // Much larger icons
        padding: EdgeInsets.zero, // Remove default padding
      ),
    );
  }
}