// lib\components\ui\app_message_bubble.dart
import 'dart:io';

import 'package:ai_chatbot_app/models/generated_image.dart';
import 'package:ai_chatbot_app/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/agate.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_message.dart';
import '../../widgets/generated_image_viewer.dart';

class UserMessageBubble extends StatelessWidget {
  final ChatMessage message; // Changed from String to ChatMessage

  const UserMessageBubble({
    super.key,
    required this.message,
  });

  Widget _buildAvatar(BuildContext context, String? avatarUrl) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (avatarUrl != null &&
        (avatarUrl.contains('dicebear.com') || avatarUrl.contains('/svg'))) {
      return SvgPicture.network(
        avatarUrl,
        width: 28,
        height: 28,
        placeholderBuilder: (context) => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryColor, colorScheme.secondary],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.onSurface.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.person,
            color: colorScheme.onPrimary,
            size: 16,
          ),
        ),
        fit: BoxFit.cover,
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.onSurface.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 12,
          backgroundImage: NetworkImage(avatarUrl),
        ),
      );
    } else {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, colorScheme.secondary],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.onSurface.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.person,
          color: colorScheme.onPrimary,
          size: 16,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = Provider.of<AuthProvider>(context).userPhotoUrl;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primaryColor,
                    colorScheme.secondary,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.displayText, // Use displayText instead of direct text
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildAvatar(context, avatarUrl),
        ],
      ),
    );
  }
}

class BotMessageBubble extends StatefulWidget {
  final ChatMessage message; // Changed from String to ChatMessage
  final VoidCallback onSpeak;
  final VoidCallback onCopy;

  const BotMessageBubble({
    super.key,
    required this.message,
    required this.onSpeak,
    required this.onCopy,
  });

  @override
  State<BotMessageBubble> createState() => _BotMessageBubbleState();
}

class _BotMessageBubbleState extends State<BotMessageBubble>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _copyPressed = false;
  bool _speakPressed = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handleCopy() async {
    if (_copyPressed) return;
    
    setState(() => _copyPressed = true);
    HapticFeedback.lightImpact();
    widget.onCopy();
    
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      setState(() => _copyPressed = false);
    }
  }

  void _handleSpeak() async {
    if (_speakPressed) return;
    
    setState(() => _speakPressed = true);
    HapticFeedback.lightImpact();
    widget.onSpeak();
    
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      setState(() => _speakPressed = false);
    }
  }

  Widget _buildBotAvatar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceVariant ?? colorScheme.surface,
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/bot_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.auto_awesome,
              color: theme.primaryColor,
              size: 14,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (widget.message.isImageMessage && widget.message.imageData != null) {
      // Display generated image preview (tappable to open full viewer)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image prompt
          if (widget.message.imageData!.prompt.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Generated image: "${widget.message.imageData!.prompt}"',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          
          // Tappable image preview
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GeneratedImageViewer(
                    image: widget.message.imageData!,
                  ),
                ),
              );
            },
            child: Hero(
              tag: 'image_${widget.message.imageData!.id}',
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 400,  // Bound height to prevent overflow
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FutureBuilder<bool>(
                    future: _isOnline(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingWidget(context, null);
                      }
                      final isOnline = snapshot.data ?? true;

                      if (widget.message.imageData!.bestSource == ImageSource.network && isOnline) {
                        return Image.network(
                          widget.message.imageData!.imageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildLoadingWidget(context, loadingProgress);
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              _buildErrorWidget(context, isConnectivityError: !isOnline),
                        );
                      } else if (widget.message.imageData!.hasLocalData) {
                        return Image.memory(
                          widget.message.imageData!.imageData,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildErrorWidget(context, isConnectivityError: false),
                        );
                      } else if (widget.message.imageData!.hasCachedFile) {
                        return Image.file(
                          File(widget.message.imageData!.localPath!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildErrorWidget(context, isConnectivityError: false),
                        );
                      } else {
                        return _buildErrorWidget(context, isConnectivityError: !isOnline);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Image details
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant?.withOpacity(0.5) ?? 
                     colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Image Details',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.message.imageData!.getDescription(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Display text message with markdown
      return MarkdownBody(
        data: widget.message.text,
        selectable: true,
        styleSheet: _buildMarkdownStyleSheet(context),
        builders: {
          'code': CodeBlockBuilder(),
        },
      );
    }
  }

  Widget _buildLoadingWidget(BuildContext context, ImageChunkEvent? loadingProgress) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final progress = loadingProgress != null
        ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
        : 0.0;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading image...',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          if (progress > 0)
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, {bool isConnectivityError = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnectivityError ? Icons.signal_wifi_off : Icons.broken_image_outlined,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            isConnectivityError ? 'No internet connection' : 'Failed to load image',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConnectivityError 
                ? 'Please check your connection and try again' 
                : 'The image may have been corrupted or deleted',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.only(right: 48, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              child: _buildBotAvatar(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageContent(context),
                  ),
                  
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        if (!widget.message.isImageMessage) // Only show speak button for text
                          _buildActionButton(
                            context: context,
                            icon: Icons.volume_up_rounded,
                            onPressed: _handleSpeak,
                            isPressed: _speakPressed,
                            tooltip: 'Read aloud',
                          ),
                        if (!widget.message.isImageMessage) // Only show copy button for text
                          const SizedBox(width: 8),
                        if (!widget.message.isImageMessage)
                          _buildActionButton(
                            context: context,
                            icon: Icons.copy_rounded,
                            onPressed: _handleCopy,
                            isPressed: _copyPressed,
                            tooltip: 'Copy text',
                          ),
                        // For image messages, the GeneratedImageViewer handles its own action buttons
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isPressed = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Transform.scale(
      scale: isPressed ? 0.9 : 1.0,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Icon(
              icon,
              size: 16,
              color: theme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return MarkdownStyleSheet(
      p: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: colorScheme.onSurface.withOpacity(0.8),
        height: 1.5,
      ),
      
      h1: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: colorScheme.onSurface,
        height: 1.3,
      ),
      h2: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 19,
        color: colorScheme.onSurface,
        height: 1.3,
      ),
      h3: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
        fontSize: 17,
        color: colorScheme.onSurface,
        height: 1.3,
      ),
      
      code: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 13,
        color: theme.primaryColor,
        backgroundColor: (colorScheme.surfaceVariant ?? colorScheme.surface).withOpacity(0.5),
      ),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceVariant ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      
      strong: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: colorScheme.onSurface,
      ),
      em: TextStyle(
        fontFamily: 'Poppins',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: colorScheme.onSurface.withOpacity(0.8),
      ),
      
      a: TextStyle(
        color: theme.primaryColor,
        decoration: TextDecoration.underline,
        decorationColor: theme.primaryColor.withOpacity(0.6),
        fontSize: 15,
      ),
      
      listBullet: TextStyle(
        color: colorScheme.onSurface.withOpacity(0.8),
        fontSize: 15,
      ),
      listIndent: 20.0,
      
      blockquote: TextStyle(
        color: colorScheme.onSurface.withOpacity(0.6),
        fontStyle: FontStyle.italic,
        fontSize: 15,
        height: 1.5,
      ),
      blockquoteDecoration: BoxDecoration(
        color: (colorScheme.surfaceVariant ?? colorScheme.surface).withOpacity(0.3),
        border: Border(
          left: BorderSide(
            color: theme.primaryColor,
            width: 3.0,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      blockquotePadding: const EdgeInsets.all(12),
      
      tableHead: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      tableBody: TextStyle(
        color: colorScheme.onSurface.withOpacity(0.8),
        fontSize: 13,
      ),
      tableBorder: TableBorder.all(
        color: colorScheme.outline.withOpacity(0.1),
        width: 1.0,
        borderRadius: BorderRadius.circular(6),
      ),
      tableCellsPadding: const EdgeInsets.all(10),
      
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1.0,
          ),
        ),
      ),
    );
  }
    }
  class CodeBlockBuilder extends MarkdownElementBuilder {
    @override
    Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
      String language = element.attributes['class']?.replaceFirst('language-', '') ?? '';
      String code = element.textContent;

      if (language.isNotEmpty) {
        return Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final isDark = theme.brightness == Brightness.dark;
            
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant ?? colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.code_rounded,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          language.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: HighlightView(
                      code,
                      language: language,
                      theme: isDark ? agateTheme : githubTheme,
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
      
      return null;
    }
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
