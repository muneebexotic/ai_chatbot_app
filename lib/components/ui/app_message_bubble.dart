import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/agate.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../components/ui/app_text.dart';

class UserMessageBubble extends StatelessWidget {
  final String message;

  const UserMessageBubble({
    super.key,
    required this.message,
  });

  Widget _buildAvatar(String? avatarUrl) {
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
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textPrimary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.person,
            color: AppColors.textPrimary,
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
            color: AppColors.textPrimary.withOpacity(0.2),
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
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textPrimary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.person,
          color: AppColors.textPrimary,
          size: 16,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = Provider.of<AuthProvider>(context).userPhotoUrl;

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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
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
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // User avatar positioned at bottom edge
          _buildAvatar(avatarUrl),
        ],
      ),
    );
  }
}

class BotMessageBubble extends StatefulWidget {
  final String message;
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

  Widget _buildBotAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceVariant,
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
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
              color: AppColors.primary,
              size: 14,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.only(right: 48, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot avatar positioned at top edge
            Container(
              margin: const EdgeInsets.only(top: 2),
              child: _buildBotAvatar(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: MarkdownBody(
                      data: widget.message,
                      selectable: true,
                      styleSheet: _buildMarkdownStyleSheet(),
                      builders: {
                        'code': CodeBlockBuilder(),
                      },
                    ),
                  ),
                  
                  // Action buttons - always visible
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        _buildActionButton(
                          icon: Icons.volume_up_rounded,
                          onPressed: _handleSpeak,
                          isPressed: _speakPressed,
                          tooltip: 'Read aloud',
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.copy_rounded,
                          onPressed: _handleCopy,
                          isPressed: _copyPressed,
                          tooltip: 'Copy text',
                        ),
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
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isPressed = false,
  }) {
    return Transform.scale(
      scale: isPressed ? 0.9 : 1.0,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
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
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      // Base text style
      p: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      
      // Headings
      h1: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      h2: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 19,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      h3: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
        fontSize: 17,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      
      // Code styling
      code: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 13,
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant.withOpacity(0.5),
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textTertiary.withOpacity(0.1),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      
      // Text formatting
      strong: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      em: TextStyle(
        fontFamily: 'Poppins',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontSize: 15,
        color: AppColors.textSecondary,
      ),
      
      // Links
      a: TextStyle(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primary.withOpacity(0.6),
        fontSize: 15,
      ),
      
      // Lists
      listBullet: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
      ),
      listIndent: 20.0,
      
      // Blockquotes
      blockquote: TextStyle(
        color: AppColors.textTertiary,
        fontStyle: FontStyle.italic,
        fontSize: 15,
        height: 1.5,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.3),
        border: Border(
          left: BorderSide(
            color: AppColors.primary,
            width: 3.0,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      blockquotePadding: const EdgeInsets.all(12),
      
      // Tables
      tableHead: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      tableBody: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      tableBorder: TableBorder.all(
        color: AppColors.textTertiary.withOpacity(0.1),
        width: 1.0,
        borderRadius: BorderRadius.circular(6),
      ),
      tableCellsPadding: const EdgeInsets.all(10),
      
      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.textTertiary.withOpacity(0.1),
            width: 1.0,
          ),
        ),
      ),
    );
  }
}

// Enhanced code block builder
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String language = element.attributes['class']?.replaceFirst('language-', '') ?? '';
    String code = element.textContent;

    if (language.isNotEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textTertiary.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
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
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    language.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Code content
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: HighlightView(
                code,
                language: language,
                theme: agateTheme,
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
    
    return null;
  }
}