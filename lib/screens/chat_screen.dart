import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/themes_provider.dart';
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
import '../screens/subscription_screen.dart';
import '../services/payment_service.dart';

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

  Future<bool> _onWillPop() async {
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (chatProvider.isTyping) {
        return false;
      }

      final shouldExit = await _showExitDialog();
      return shouldExit ?? false;
    } catch (e) {
      debugPrint('Error in _onWillPop: $e');
      return true;
    }
  }

  Future<bool?> _showExitDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    
    try {
      return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          backgroundColor: AppColors.getSurface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.exit_to_app,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppText.displayMedium(
                  'Exit App?',
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.bodyMedium(
                'Are you sure you want to exit the app?',
                color: AppColors.getTextSecondary(isDark),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText.bodySmall(
                        'Your conversations will be saved and available when you return.',
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: AppText.bodyMedium(
                'Cancel',
                color: AppColors.getTextSecondary(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: AppText.bodyMedium(
                'Exit',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing exit dialog: $e');
      return false;
    }
  }

  Future<void> _startListening() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!await authProvider.canSendVoice()) {
      _showUpgradeDialog(
        'Voice Limit Reached',
        'You\'ve reached your daily limit of ${PaymentService.FREE_DAILY_VOICE} voice messages.',
        'Upgrade to Premium for unlimited voice messages!',
      );
      return;
    }

    HapticFeedback.lightImpact();
    
    final available = await _speechService.startListening(
      onResult: (text) => setState(() => _controller.text = text),
      onDone: () async {
        setState(() => _isListening = false);
        await authProvider.incrementVoiceUsage();
      },
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

  void _handleSend() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!await authProvider.canSendMessage()) {
      _showUpgradeDialog(
        'Message Limit Reached',
        'You\'ve reached your daily limit of ${PaymentService.FREE_DAILY_MESSAGES} messages.',
        'Upgrade to Premium for unlimited messages!',
      );
      return;
    }

    HapticFeedback.selectionClick();
    _controller.clear();
    _focusNode.unfocus();

    try {
      await Provider.of<ChatProvider>(context, listen: false).sendMessage(message);
      await authProvider.incrementMessageUsage();
      _scrollToTop();
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    }
  }

  void _showUpgradeDialog(String title, String description, String benefits) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.star, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppText.displayMedium(
                title,
                color: AppColors.getTextPrimary(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.bodyMedium(
              description,
              color: AppColors.getTextSecondary(isDark),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.bodyMedium(
                    'Premium Benefits:',
                    color: AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 8),
                  AppText.bodySmall(
                    '• Unlimited messages\n• Unlimited images & voice\n• All personas unlocked\n• Priority support',
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText.bodySmall(
                          auth.usageText,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: AppText.bodyMedium(
              'Later',
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: AppText.bodyMedium(
              'Upgrade Now',
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  AppText.bodyLarge(
                    'Quick Suggestions',
                    color: AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.getTextSecondary(isDark)),
                  ),
                ],
              ),
            ),
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
              title: AppText.bodyMedium(suggestion, color: AppColors.getTextPrimary(isDark)),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: AppColors.getTextTertiary(isDark),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDark;
        
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                
                AppText.displayLarge(
                  'How can I help you today?',
                  color: AppColors.getTextPrimary(isDark),
                  textAlign: TextAlign.center,
                  fontWeight: FontWeight.w600,
                ),
                
                const SizedBox(height: 12),
                
                AppText.bodyMedium(
                  'Choose a topic below or start typing your question',
                  color: AppColors.getTextSecondary(isDark),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 48),
                
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
                
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.isPremium) return const SizedBox.shrink();
                    
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText.bodyMedium(
                                      'Daily Usage',
                                      color: AppColors.getTextPrimary(isDark),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    const SizedBox(height: 4),
                                    AppText.bodySmall(
                                      authProvider.usageText,
                                      color: AppColors.getTextSecondary(isDark),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SubscriptionScreen(),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: AppText.bodySmall(
                                'Upgrade for Unlimited Access',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
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
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(String title) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDark;
        
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getBackground(isDark).withOpacity(0.9),
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
                icon: Icon(Icons.menu, color: AppColors.getTextPrimary(isDark)),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: AppText.bodyLarge(
              title,
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
            centerTitle: true,
            actions: [
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.isPremium) {
                    return IconButton(
                      icon: Icon(Icons.star, color: AppColors.primary, size: 20),
                      onPressed: () {},
                      tooltip: 'Premium User',
                    );
                  }
                  
                  return IconButton(
                    icon: Stack(
                      children: [
                        Icon(Icons.show_chart, color: AppColors.getTextSecondary(isDark)),
                        if (!authProvider.isPremium)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () => _showUsageDialog(authProvider),
                    tooltip: 'Usage Status',
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.getTextPrimary(isDark)),
                color: AppColors.getSurface(isDark),
                onSelected: _handleMenuSelection,
                itemBuilder: (_) => [
                  _buildMenuItem('clear', 'Clear Chat', Icons.clear_all, isDark),
                  _buildMenuItem('rename', 'Rename', Icons.edit, isDark),
                  _buildMenuItem('delete', 'Delete', Icons.delete_outline, isDark),
                  _buildMenuItem('settings', 'Settings', Icons.settings, isDark),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUsageDialog(AuthProvider authProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.show_chart, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            AppText.displayMedium(
              'Daily Usage',
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.bodyMedium(
              authProvider.usageText,
              color: AppColors.getTextSecondary(isDark),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.bodyMedium(
                    'Free Plan Limits:',
                    color: AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 8),
                  AppText.bodySmall(
                    '• ${PaymentService.FREE_DAILY_MESSAGES} messages per day\n• ${PaymentService.FREE_DAILY_IMAGES} images per day\n• ${PaymentService.FREE_DAILY_VOICE} voice inputs per day\n• ${PaymentService.FREE_PERSONAS_COUNT} personas available',
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: AppText.bodyMedium(
              'Close',
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: AppText.bodyMedium(
              'Upgrade',
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String label, IconData icon, bool isDark) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppColors.getTextSecondary(isDark), size: 18),
          const SizedBox(width: 12),
          AppText.bodyMedium(label, color: AppColors.getTextPrimary(isDark)),
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
      orElse: () => ConversationSummary(id: '', title: '', createdAt: DateTime.now()),
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText.displayMedium('Delete Chat', color: AppColors.getTextPrimary(isDark)),
        content: AppText.bodyMedium(
          'Are you sure you want to delete this chat? This action cannot be undone.',
          color: AppColors.getTextSecondary(isDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: AppText.bodyMedium('Cancel', color: AppColors.getTextSecondary(isDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: AppText.bodyMedium('Delete', color: Colors.white),
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
          orElse: () => ConversationSummary(id: '', title: 'New Chat', createdAt: DateTime.now()),
        )
        .title;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDark;
        
        return WillPopScope(
          onWillPop: _onWillPop,
          child: GestureDetector(
            onTap: () => _focusNode.unfocus(),
            child: Scaffold(
              backgroundColor: AppColors.getBackground(isDark),
              drawer: ConversationDrawer(
                onRenameDialog: _showRenameDialog,
                onDrawerClosed: () {
                  Provider.of<ConversationsProvider>(context, listen: false).clearSearch();
                },
              ),
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.getBackground(isDark),
                      AppColors.getSurface(isDark),
                      AppColors.getBackground(isDark),
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
          ),
        );
      },
    );
  }
}