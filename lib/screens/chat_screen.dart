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

  // Chip data structure
  final List<Map<String, dynamic>> _chipData = [
    {
      'label': 'Brainstorm',
      'icon': Icons.lightbulb_outline,
      'suggestions': [
        'Help me brainstorm ideas for a new project',
        'Generate creative solutions for problem-solving',
        'What are some innovative approaches to marketing',
        'Brainstorm unique business name ideas'
      ]
    },
    {
      'label': 'Create Image',
      'icon': Icons.image_outlined,
      'suggestions': [
        'Generate a beautiful landscape image',
        'Create an abstract art piece',
        'Design a logo for my business',
        'Make a cartoon character illustration'
      ]
    },
    {
      'label': 'Get Advice',
      'icon': Icons.psychology_outlined,
      'suggestions': [
        'Give me advice on career development',
        'How to improve my communication skills',
        'Tips for maintaining work-life balance',
        'Advice on building healthy relationships'
      ]
    },
    {
      'label': 'Make a Plan',
      'icon': Icons.calendar_today_outlined,
      'suggestions': [
        'Create a 30-day fitness plan',
        'Plan a weekend trip itinerary',
        'Make a study schedule for exams',
        'Design a meal prep plan for the week'
      ]
    },
    {
      'label': 'Surprise Me',
      'icon': Icons.auto_awesome_outlined,
      'suggestions': [
        'Tell me an interesting random fact',
        'Share a fun riddle or brain teaser',
        'Recommend something new to try today',
        'Give me a creative writing prompt'
      ]
    },
    {
      'label': 'Generate Images',
      'icon': Icons.palette_outlined,
      'suggestions': [
        'Create a futuristic city skyline',
        'Generate a cozy coffee shop interior',
        'Design a minimalist poster',
        'Make a fantasy creature illustration'
      ]
    },
    {
      'label': 'Help Me Write',
      'icon': Icons.edit_outlined,
      'suggestions': [
        'Write a professional email template',
        'Help me draft a resume summary',
        'Create a compelling story opening',
        'Write a persuasive product description'
      ]
    },
    {
      'label': 'Pamper Me',
      'icon': Icons.spa_outlined,
      'suggestions': [
        'Suggest a relaxing evening routine',
        'Recommend self-care activities',
        'Create a meditation script',
        'Give me compliments and motivation'
      ]
    },
  ];

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

  void _showChipModal(BuildContext context, List<String> suggestions) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              bottom: 120, // Position above the text field
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF141718),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: suggestions.map((suggestion) {
                      return InkWell(
                        onTap: () {
                          _controller.text = suggestion;
                          Navigator.of(context).pop();
                          _focusNode.requestFocus();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            suggestion,
                            style: const TextStyle(
                              fontFamily: 'Urbanist',
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChip(Map<String, dynamic> chipData) {
    return GestureDetector(
      onTap: () => _showChipModal(context, chipData['suggestions']),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chipData['icon'],
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              chipData['label'],
              style: const TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'What can I help with?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _chipData.map((chipData) => _buildChip(chipData)).toList(),
            ),
          ),
        ],
      ),
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
        backgroundColor: Colors.black,
        drawer: Drawer(
          backgroundColor: Color(0xFF141718),
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
          backgroundColor: Colors.black,
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
              fontSize: 22,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
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
              child: chatProvider.messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
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
                            color: isUser ? Color(0xFF141718) : Colors.black,
                            //borderRadius: BorderRadius.circular(12),
                          ),
                          child: isUser
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment
                                      .center, // Changed from .start to .center
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundImage: AssetImage(
                                        'assets/images/user_avatar.png',
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
                                        Image.asset('assets/images/bot_icon.png'),
                                        //const Icon(Icons.smart_toy, size: 20),
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
                      cursorColor: Colors.white,
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        filled: true,
                        fillColor: Color.fromARGB(255, 66, 73, 75),
                        hintStyle: TextStyle(
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(34),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(34),
                          borderSide: BorderSide(
                            color: Colors.white,
                          ), // White border when focused
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
                                _isListening ? Icons.mic : Icons.mic_none,
                              ),
                              onPressed: _startListening,
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _handleSend,
                            ),
                          ],
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
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