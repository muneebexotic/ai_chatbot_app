import 'package:flutter/material.dart';

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
                icon: const Icon(Icons.volume_up, size: 20),
                onPressed: onSpeak,
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: onCopy,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Urbanist',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Color(0xFFA0A0A5),
            ),
          ),
        ],
      ),
    );
  }
}
