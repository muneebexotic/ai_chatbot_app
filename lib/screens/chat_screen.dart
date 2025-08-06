import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../components/ui/app_text.dart';
import '../utils/app_theme.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/message_input_field.dart';
import '../components/ui/app_message_bubble.dart';
import '../widgets/suggestion_chip.dart';
import '../constants/suggestion_data.dart';
import '../widgets/conversation_drawer.dart';
import '../services/voice_service.dart';
import '../services/clipboard_service.dart';
import '../services/speech_service.dart';
import '../widgets/rename_conversation_dialog.dart';
import '../models/conversation.dart';

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
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final showFab = _scrollController.hasClients &&
          _scrollController.offset > 200;
      
      if (showFab != _showScrollToTop) {
        setState(() => _showScrollToTop = showFab);
      }
    });
  }

  Future<void> _startListening() async {
    HapticFeedback.lightImpact();
    
    final available = await _speechService.startListening(
      onResult: (text) => setState(() => _controller.text = text),
      onDone: () => setState(() => _isListening = false),
      onError: (msg) {
        _showErrorSnackBar(msg);
        setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() => _isListening = true);
    } else {
      _showErrorSnackBar('Microphone not available');
    }
  }

  Future<String?> _showRenameDialog(BuildContext context, String currentTitle) {
    return showDialog<String>(
      context: context,
      builder: (context) => RenameConversationDialog(currentTitle: currentTitle),
    );
  }
  
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleSend() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    HapticFeedback.selectionClick();
    _controller.clear();
    _focusNode.unfocus();

    Provider.of<ChatProvider>(context, listen: false)
        .sendMessage(message)
        .then((_) => _scrollToTop());
  }

  void _scrollToTop() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSuggestionModal(List<String> suggestions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.textTertiary.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  AppText.bodyLarge(
                    'Quick Suggestions',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Suggestions
            ...suggestions.map((suggestion) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              title: AppText.bodyMedium(suggestion, color: AppColors.textPrimary),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textTertiary,
                size: 14,
              ),
              onTap: () {
                _controller.text = suggestion;
                Navigator.pop(context);
                _focusNode.requestFocus();
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Welcome icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Welcome message
            AppText.displayLarge(
              'How can I help you today?',
              color: AppColors.textPrimary,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.w600,
            ),
            
            const SizedBox(height: 12),
            
            AppText.bodyMedium(
              'Choose a topic below or start typing your question',
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 48),
            
            // Suggestion chips
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: suggestionChipData.map((chipData) => 
                SuggestionChip(
                  label: chipData['label'],
                  icon: chipData['icon'],
                  suggestions: chipData['suggestions'],
                  onTap: _showSuggestionModal,
                ),
              ).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // Tip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText.bodySmall(
                      'Tap the microphone to use voice input',
                      color: AppColors.textSecondary,
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

  Widget _buildAppBar(String title) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withOpacity(0.1),
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: AppText.bodyLarge(
          title,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.surface,
            onSelected: _handleMenuSelection,
            itemBuilder: (_) => [
              _buildMenuItem('clear', 'Clear Chat', Icons.clear_all),
              _buildMenuItem('rename', 'Rename', Icons.edit),
              _buildMenuItem('delete', 'Delete', Icons.delete_outline),
              _buildMenuItem('settings', 'Settings', Icons.settings),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          AppText.bodyMedium(label, color: AppColors.textPrimary),
        ],
      ),
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final convoProvider = Provider.of<ConversationsProvider>(context, listen: false);

    switch (value) {
      case 'clear':
        chatProvider.deleteChat();
        break;
      case 'rename':
        await _handleRename(convoProvider, chatProvider);
        break;
      case 'delete':
        await _handleDelete(chatProvider, convoProvider);
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }

  Future<void> _handleRename(ConversationsProvider convoProvider, ChatProvider chatProvider) async {
    final convo = convoProvider.conversations.firstWhere(
      (c) => c.id == chatProvider.conversationId,
      orElse: () => ConversationSummary(id: '', title: '', createdAt: ''),
    );
    
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => RenameConversationDialog(currentTitle: convo.title),
    );
    
    if (newTitle != null && newTitle.trim().isNotEmpty) {
      await convoProvider.renameConversation(convo.id, newTitle.trim());
    }
  }

  Future<void> _handleDelete(ChatProvider chatProvider, ConversationsProvider convoProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText.displayMedium('Delete Chat', color: AppColors.textPrimary),
        content: AppText.bodyMedium(
          'Are you sure you want to delete this chat? This action cannot be undone.',
          color: AppColors.textSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: AppText.bodyMedium('Cancel', color: AppColors.textSecondary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: AppText.bodyMedium('Delete', color: AppColors.textPrimary),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await chatProvider.deleteConversation();
      await convoProvider.loadConversations();
    }
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

    final currentTitle = convoProvider.conversations
        .firstWhere(
          (c) => c.id == chatProvider.conversationId,
          orElse: () => ConversationSummary(id: '', title: 'New Chat', createdAt: ''),
        )
        .title;

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: ConversationDrawer(
          onRenameDialog: _showRenameDialog,
          onDrawerClosed: () {
            Provider.of<ConversationsProvider>(context, listen: false).clearSearch();
          },
        ),
        // floatingActionButton: _showScrollToTop
        //     ? Positioned(
        //         left: 32,
        //         bottom: 100,
        //         child: FloatingActionButton(
        //           mini: true,
        //           backgroundColor: AppColors.primary,
        //           onPressed: _scrollToTop,
        //           child: Icon(Icons.keyboard_arrow_up, color: AppColors.textPrimary),
        //         ),
        //       )
        //     : null,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                AppColors.surface,
                AppColors.background,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            children: [
              SafeArea(bottom: false, child: _buildAppBar(currentTitle)),
              
              Expanded(
                child: chatProvider.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatProvider.messages.length,
                        itemBuilder: (context, index) {
                          final reverseIndex = chatProvider.messages.length - 1 - index;
                          final msg = chatProvider.messages[reverseIndex];
                          final isUser = msg.sender == 'user';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: isUser
                                ? UserMessageBubble(message: msg.text)
                                : BotMessageBubble(
                                    message: msg.text,
                                    onSpeak: () => _voiceService.speak(msg.text),
                                    onCopy: () {
                                      ClipboardService.copyText(msg.text);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Copied to clipboard',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          backgroundColor: AppColors.success,
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          );
                        },
                      ),
              ),
              
              if (chatProvider.isTyping)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(child: ModernTypingIndicator()),
                    ],
                  ),
                ),
                
              Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  top: 8,
                  left: 8,
                  right: 8,
                ),
                child: MessageInputField(
                  controller: _controller,
                  focusNode: _focusNode,
                  isListening: _isListening,
                  onMicTap: _startListening,
                  onSend: _handleSend,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}