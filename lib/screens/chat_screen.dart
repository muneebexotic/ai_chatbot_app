import 'package:ai_chatbot_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../models/chat_message.dart';
import 'package:ai_chatbot_app/providers/themes_provider.dart';
import '../widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final FlutterTts _tts = FlutterTts();

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (val) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone error or permission denied'),
          ),
        );
        setState(() => _isListening = false);
      },
    );

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mic permission denied or not available')),
      );
      return;
    }

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (val) {
        setState(() {
          _controller.text = val.recognizedWords;
        });
      },
    );
  }

  void _speak(String text) async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  void _copyText(String text) {
    FlutterClipboard.copy(text).then((_) {
      Fluttertoast.showToast(msg: 'Copied to clipboard');
    });
  }

  void _handleSend() {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    _controller.clear();
    _focusNode.unfocus();

    Provider.of<ChatProvider>(context, listen: false).sendMessage(message).then(
      (_) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final convoProvider = Provider.of<ConversationsProvider>(context);

    // Get current conversation title safely
    final currentTitle = convoProvider.conversations
        .firstWhere(
          (c) => c.id == chatProvider.conversationId,
          orElse: () =>
              ConversationSummary(id: '', title: 'New Chat', createdAt: ''),
        )
        .title;

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: Scaffold(
        drawer: Drawer(
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
                                    final newTitle = await _showRenameDialog(
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
                                    if (convo.id ==
                                        chatProvider.conversationId) {
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
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          centerTitle: true,
          title: Text(
            currentTitle,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'clear':
                    chatProvider.deleteChat();
                    break;
                  case 'rename':
                    final convo = convoProvider.conversations.firstWhere(
                      (c) => c.id == chatProvider.conversationId,
                      orElse: () =>
                          ConversationSummary(id: '', title: '', createdAt: ''),
                    );
                    final newTitle = await _showRenameDialog(
                      context,
                      convo.title,
                    );
                    if (newTitle != null && newTitle.trim().isNotEmpty) {
                      await convoProvider.renameConversation(
                        convo.id,
                        newTitle.trim(),
                      );
                    }
                    break;
                  case 'delete':
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Chat'),
                        content: const Text(
                          'Are you sure you want to delete this chat?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await chatProvider.deleteConversation();
                      await convoProvider.loadConversations();
                    }
                    break;
                  case 'settings':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename Conversation'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Conversation'),
                ),
                const PopupMenuItem(value: 'settings', child: Text('Settings')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: chatProvider.messages.length,
                itemBuilder: (context, index) {
                  final msg = chatProvider.messages[index];
                  final isUser = msg.sender == 'user';
                  final timeString = DateFormat(
                    'hh:mm a',
                  ).format(msg.timestamp);

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.black : Color(0xFF232627),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isUser
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                backgroundImage: AssetImage(
                                  'assets/user.png',
                                ), // or network image
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  msg.text,
                                  style: const TextStyle(
                                    fontFamily: 'Urbanist',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  // edit logic (to be implemented)
                                },
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.smart_toy, size: 20),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up, size: 20),
                                    onPressed: () => _speak(msg.text),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () => _copyText(msg.text),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg.text,
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
                },
              ),
            ),
            if (chatProvider.isTyping) const LoadingIndicator(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    onPressed: _startListening,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showRenameDialog(BuildContext context, String currentTitle) {
  final controller = TextEditingController(text: currentTitle);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
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
    ),
  );
}
