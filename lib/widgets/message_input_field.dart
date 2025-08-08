import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../screens/subscription_screen.dart';

class MessageInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final VoidCallback onMicTap;
  final VoidCallback onSend;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.onMicTap,
    required this.onSend,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField>
    with TickerProviderStateMixin {
  AnimationController? _micAnimationController;
  AnimationController? _sendAnimationController;
  AnimationController? _expandAnimationController;
  Animation<double>? _micPulseAnimation;
  Animation<double>? _sendScaleAnimation;
  Animation<double>? _expandAnimation;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _sendAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _expandAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _micPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _micAnimationController!,
      curve: Curves.easeInOut,
    ));

    _sendScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
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

    // Listen to focus changes
    widget.focusNode.addListener(() {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    });

    // Listen to text changes
    widget.controller.addListener(() {
      final hasText = widget.controller.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
        if (hasText) {
          _expandAnimationController?.forward();
        } else {
          _expandAnimationController?.reverse();
        }
      }
    });

    // Start mic animation if listening
    if (widget.isListening) {
      _micAnimationController?.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MessageInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle mic animation based on listening state
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
    super.dispose();
  }

  // CRITICAL FIX: Add usage limit check for sending messages
  Future<void> _handleSendTap() async {
    // Check if user can send message
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canSend = await authProvider.canSendMessage();
    
    if (!canSend) {
      _showUsageLimitDialog('message');
      return;
    }

    _sendAnimationController?.forward().then((_) {
      _sendAnimationController?.reverse();
      widget.onSend();
    });
  }

  // CRITICAL FIX: Add usage limit check for voice messages
  Future<void> _handleMicTap() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canSendVoice = await authProvider.canSendVoice();
    
    if (!canSendVoice) {
      _showUsageLimitDialog('voice');
      return;
    }

    widget.onMicTap();
  }

  // CRITICAL FIX: Add usage limit check for image uploads
  Future<void> _handleImageUpload() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canUpload = await authProvider.canUploadImage();
    
    if (!canUpload) {
      _showUsageLimitDialog('image');
      return;
    }

    // Show "Coming soon" for now
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Image upload coming soon!',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // CRITICAL FIX: Usage limit dialog
  void _showUsageLimitDialog(String limitType) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Daily Limit Reached',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'ve reached your daily $limitType limit for free users.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                authProvider.usageText,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
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
                    Text(
                      'Upgrade to Premium for:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Unlimited messages\n• All personas\n• Unlimited images & voice\n• Priority support',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Later',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
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
              child: Text(
                'Upgrade',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
          child: Row(
            children: [
              // Main input container with dynamic width
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: _isFocused
                        ? Border.all(
                            color: AppColors.primary.withOpacity(0.6),
                            width: 2,
                          )
                        : Border.all(
                            color: AppColors.surfaceVariant.withOpacity(0.3),
                            width: 1,
                          ),
                    boxShadow: _isFocused
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
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
                            color: AppColors.textPrimary,
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
                              color: AppColors.textTertiary,
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
                          ),
                          onSubmitted: (_) => _handleSendTap(),
                        ),
                      ),
                      
                      // Icons inside the input field
                      AnimatedBuilder(
                        animation: _expandAnimation ?? AlwaysStoppedAnimation(0.0),
                        builder: (context, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // File attachment icon (visible when no text)
                              if (!_hasText) ...[
                                IconButton(
                                  onPressed: _handleImageUpload,
                                  icon: const Icon(Icons.attach_file),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Attach file',
                                ),
                                
                                // Camera icon (visible when no text)
                                IconButton(
                                  onPressed: _handleImageUpload,
                                  icon: const Icon(Icons.camera_alt),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Take photo',
                                ),
                              ],
                              
                              // Clip icon (visible when has text, replaces camera)
                              if (_hasText) ...[
                                Transform.scale(
                                  scale: _expandAnimation?.value ?? 0.0,
                                  child: Opacity(
                                    opacity: _expandAnimation?.value ?? 0.0,
                                    child: IconButton(
                                      onPressed: _handleImageUpload,
                                      icon: const Icon(Icons.attach_file),
                                      color: AppColors.textSecondary,
                                      tooltip: 'Attach file',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Voice/Send button (outside the input field)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _micPulseAnimation ?? AlwaysStoppedAnimation(1.0),
                  _sendScaleAnimation ?? AlwaysStoppedAnimation(1.0),
                ]),
                builder: (context, child) {
                  final micAnimationValue = _micPulseAnimation?.value ?? 1.0;
                  final sendAnimationValue = _sendScaleAnimation?.value ?? 1.0;
                  
                  // Check if buttons should be disabled
                  final canSendMessage = authProvider.isPremium || authProvider.paymentService.remainingMessages > 0;
                  final canSendVoice = authProvider.isPremium || authProvider.paymentService.remainingVoice > 0;
                  final isEnabled = _hasText ? canSendMessage : canSendVoice;
                  
                  return Transform.scale(
                    scale: _hasText 
                        ? sendAnimationValue 
                        : (widget.isListening ? micAnimationValue : 1.0),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _hasText || widget.isListening
                              ? (isEnabled 
                                  ? [AppColors.primary, AppColors.secondary]
                                  : [AppColors.textTertiary.withOpacity(0.5), AppColors.textTertiary.withOpacity(0.3)])
                              : [AppColors.surface, AppColors.surfaceVariant],
                        ),
                        shape: BoxShape.circle,
                        border: !_hasText && !widget.isListening
                            ? Border.all(
                                color: AppColors.textTertiary.withOpacity(0.3),
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
                                  color: Colors.black.withOpacity(0.1),
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
                              : (widget.isListening ? Icons.mic : Icons.mic_none),
                          color: isEnabled
                              ? (_hasText || widget.isListening
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary)
                              : AppColors.textTertiary.withOpacity(0.5),
                          size: 22,
                        ),
                        tooltip: _hasText 
                            ? (canSendMessage ? 'Send message' : 'Daily message limit reached')
                            : (widget.isListening 
                                ? 'Stop recording' 
                                : (canSendVoice ? 'Start recording' : 'Daily voice limit reached')),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}