import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';

class ConversationDrawer extends StatelessWidget {
  final Future<String?> Function(BuildContext, String) onRenameDialog;

  const ConversationDrawer({
    super.key,
    required this.onRenameDialog,
  });

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final convoProvider = Provider.of<ConversationsProvider>(context);

    return Drawer(
      backgroundColor: const Color(0xFF141718),
      child: Column(
        children: [
          const DrawerHeader(
            child: Text('Conversations', style: TextStyle(fontSize: 20)),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New Chat'),
            onTap: () async {
              Navigator.pop(context);
              await chatProvider.startNewConversation();
              await convoProvider.loadConversations();
            },
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: convoProvider.conversations.length,
              itemBuilder: (context, index) {
                final convo = convoProvider.conversations[index];
                final isSelected = convo.id == chatProvider.conversationId;

                return ListTile(
                  title: Text(
                    convo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: isSelected,
                  onTap: () async {
                    Navigator.pop(context);
                    await chatProvider.loadConversation(convo.id);
                  },
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Rename'),
                              onTap: () async {
                                Navigator.pop(context);
                                final newTitle = await onRenameDialog(
                                  context,
                                  convo.title,
                                );
                                if (newTitle != null &&
                                    newTitle.trim().isNotEmpty) {
                                  await convoProvider.renameConversation(
                                    convo.id,
                                    newTitle.trim(),
                                  );
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete),
                              title: const Text('Delete'),
                              onTap: () async {
                                Navigator.pop(context);
                                await convoProvider.deleteConversation(
                                  convo.id,
                                );
                                if (convo.id == chatProvider.conversationId) {
                                  await chatProvider.deleteConversation();
                                }
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
