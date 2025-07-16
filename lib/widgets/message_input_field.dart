import 'package:flutter/material.dart';

class MessageInputField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          // Image icon
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image feature coming soon!'),
                  ),
                );
              },
              icon: const Icon(Icons.image_outlined),
              color: Colors.white,
              tooltip: 'Send Image',
            ),
          ),
          const SizedBox(width: 8),
          // Text input
          Expanded(
            child: TextField(
              cursorColor: Colors.white,
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                filled: true,
                fillColor: const Color.fromARGB(255, 66, 73, 75),
                hintStyle: const TextStyle(
                  fontFamily: 'Urbanist',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(34),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(34),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                      ),
                      onPressed: onMicTap,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: onSend,
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
        ],
      ),
    );
  }
}
