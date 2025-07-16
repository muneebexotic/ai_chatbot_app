import 'package:ai_chatbot_app/screens/settings_screen.dart';
import 'package:ai_chatbot_app/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/message_input_field.dart';
import '../widgets/user_message_bubble.dart';
import '../widgets/bot_message_bubble.dart';
import '../widgets/suggestion_chip.dart';
import '../constants/suggestion_data.dart';
import '../widgets/conversation_drawer.dart';
import '../services/voice_service.dart';
import '../services/clipboard_service.dart';
import '../services/speech_service.dart';
import '../widgets/rename_conversation_dialog.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final VoiceService _voiceService = VoiceService();
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
  }

  Future<String?> _showRenameDialog(BuildContext context, String currentTitle) {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          RenameConversationDialog(currentTitle: currentTitle),
    );
  }

  Future<void> _startListening() async {
    final available = await _speechService.startListening(
      onResult: (text) {
        setState(() {
          _controller.text = text;
        });
      },
      onDone: () {
        setState(() => _isListening = false);
      },
      onError: (msg) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chipData['icon'], size: 18, color: Colors.white),
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
              children: suggestionChipData.map((chipData) {
                return SuggestionChip(
                  label: chipData['label'],
                  icon: chipData['icon'],
                  suggestions: chipData['suggestions'],
                  onTap: (suggestions) => _showChipModal(context, suggestions),
                );
              }).toList(),
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
    _voiceService.stop();
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
        drawer: ConversationDrawer(onRenameDialog: _showRenameDialog),

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

                        return isUser
                            ? UserMessageBubble(
                                message: msg.text,
                                onEdit: () {
                                  // edit logic (to be implemented)
                                },
                              )
                            : BotMessageBubble(
                                message: msg.text,
                                onSpeak: () => _voiceService.speak(msg.text),
                                onCopy: () =>
                                    ClipboardService.copyText(msg.text),
                              );
                      },
                    ),
            ),
            if (chatProvider.isTyping) TypingIndicator(),
            MessageInputField(
              controller: _controller,
              focusNode: _focusNode,
              isListening: _isListening,
              onMicTap: _startListening,
              onSend: _handleSend,
            ),
          ],
        ),
      ),
    );
  }
}
