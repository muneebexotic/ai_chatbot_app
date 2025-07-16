import 'package:flutter/material.dart';

class RenameConversationDialog extends StatelessWidget {
  final String currentTitle;

  const RenameConversationDialog({
    super.key,
    required this.currentTitle,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: currentTitle);

    return AlertDialog(
      title: const Text('Rename Conversation'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Enter new title'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Rename'),
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );
  }
}
