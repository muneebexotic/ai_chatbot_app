import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/agate.dart';
import 'package:markdown/markdown.dart' as md;

class BotMessageBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/bot_icon.png'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.volume_up, size: 20, color: Colors.white),
                onPressed: onSpeak,
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: Colors.white),
                onPressed: onCopy,
              ),
            ],
          ),
          const SizedBox(height: 4),
          MarkdownBody(
            data: message,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              // Base text style
              p: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Color(0xFFA0A0A5),
              ),
              
              // Headings
              h1: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Colors.white,
              ),
              h2: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
              ),
              h3: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
              h4: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
              h5: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
              h6: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
              
              // Code styling
              code: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 14,
                color: Color(0xFFE0E0E0),
                backgroundColor: Color(0xFF2A2A2A),
              ),
              codeblockDecoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFF333333)),
                ),
              ),
              codeblockPadding: const EdgeInsets.all(12.0),
              
              // Text formatting
              strong: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFA0A0A5),
              ),
              em: const TextStyle(
                fontFamily: 'Urbanist',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Color(0xFFA0A0A5),
              ),
              del: const TextStyle(
                fontFamily: 'Urbanist',
                fontSize: 16,
                color: Color(0xFF888888),
                decoration: TextDecoration.lineThrough,
              ),
              
              // Links
              a: const TextStyle(
                color: Color(0xFF4A9EFF),
                decoration: TextDecoration.underline,
                fontSize: 16,
              ),
              
              // Lists
              listBullet: const TextStyle(
                color: Color(0xFFA0A0A5),
                fontSize: 16,
              ),
              listIndent: 24.0,
              
              // Blockquotes
              blockquote: const TextStyle(
                color: Color(0xFFB0B0B5),
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
              blockquoteDecoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  left: BorderSide(
                    color: Color(0xFF4A9EFF),
                    width: 4.0,
                  ),
                ),
              ),
              blockquotePadding: const EdgeInsets.all(12.0),
              
              // Tables
              tableHead: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tableBody: const TextStyle(
                color: Color(0xFFA0A0A5),
                fontSize: 14,
              ),
              tableBorder: TableBorder.all(
                color: const Color(0xFF333333),
                width: 1.0,
              ),
              tableHeadAlign: TextAlign.left,
              tableCellsPadding: const EdgeInsets.all(8.0),
              tableColumnWidth: const FlexColumnWidth(),
              
              // Horizontal rule
              horizontalRuleDecoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF333333),
                    width: 1.0,
                  ),
                ),
              ),
            ),
            builders: {
              'code': CodeBlockBuilder(),
            },
          ),
        ],
      ),
    );
  }
}

// Custom code block builder for syntax highlighting
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String language = element.attributes['class']?.replaceFirst('language-', '') ?? '';
    String code = element.textContent;

    if (language.isNotEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFF333333)),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
          child: HighlightView(
            code,
            language: language,
            theme: agateTheme,
            padding: const EdgeInsets.all(12.0),
            textStyle: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    return null;
  }
}