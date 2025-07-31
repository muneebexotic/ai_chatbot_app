import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

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

  void _handleSendTap() {
    _sendAnimationController?.forward().then((_) {
      _sendAnimationController?.reverse();
      widget.onSend();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
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
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'File attachment coming soon!',
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
                              },
                              icon: const Icon(Icons.attach_file),
                              color: AppColors.textSecondary,
                              tooltip: 'Attach file',
                            ),
                            
                            // Camera icon (visible when no text)
                            IconButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Camera coming soon!',
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
                              },
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
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'File attachment coming soon!',
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
                                  },
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
                      colors: _hasText
                          ? [
                              AppColors.primary,
                              AppColors.secondary,
                            ]
                          : widget.isListening
                              ? [
                                  AppColors.primary,
                                  AppColors.secondary,
                                ]
                              : [
                                  AppColors.surface,
                                  AppColors.surfaceVariant,
                                ],
                    ),
                    shape: BoxShape.circle,
                    border: !_hasText && !widget.isListening
                        ? Border.all(
                            color: AppColors.textTertiary.withOpacity(0.3),
                            width: 1,
                          )
                        : null,
                    boxShadow: _hasText || widget.isListening
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
                    onPressed: _hasText ? _handleSendTap : widget.onMicTap,
                    icon: Icon(
                      _hasText 
                          ? Icons.send_rounded
                          : (widget.isListening ? Icons.mic : Icons.mic_none),
                      color: _hasText || widget.isListening
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: _hasText 
                        ? 'Send message'
                        : (widget.isListening ? 'Stop recording' : 'Start recording'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}