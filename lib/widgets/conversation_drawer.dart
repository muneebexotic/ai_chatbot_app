import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';

class ConversationDrawer extends StatefulWidget {
  final Future<String?> Function(BuildContext, String) onRenameDialog;
  final VoidCallback? onDrawerClosed;

  const ConversationDrawer({
    super.key,
    required this.onRenameDialog,
    this.onDrawerClosed,
  });

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final convoProvider = Provider.of<ConversationsProvider>(context, listen: false);
    convoProvider.searchConversations(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    final convoProvider = Provider.of<ConversationsProvider>(context, listen: false);
    convoProvider.clearSearch();
    _searchFocusNode.unfocus();
  }

  // Clear search when drawer closes
  void _onDrawerClosed() {
    if (_searchController.text.isNotEmpty) {
      _clearSearch();
    }
    widget.onDrawerClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final convoProvider = Provider.of<ConversationsProvider>(context);

    return Drawer(
      backgroundColor: const Color(0xFF141718),
      child: Column(
        children: [
          // Header with title
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: const Row(
              children: [
                Text(
                  'Conversations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2426),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Search conversations and messages...',
                  hintStyle: TextStyle(
                    color: Colors.grey.withOpacity(0.6),
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.withOpacity(0.6),
                    size: 20,
                  ),
                  suffixIcon: convoProvider.isSearching
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.withOpacity(0.6),
                            size: 20,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // New Chat Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: const Color(0xFF1F2426),
              leading: const Icon(Icons.add, color: Colors.white),
              title: const Text(
                'New Chat',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                _onDrawerClosed(); // Clear search when creating new chat
                await chatProvider.startNewConversation();
                await convoProvider.loadConversations();
              },
            ),
          ),
          
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          
          // Conversations List
          Expanded(
            child: convoProvider.filteredConversations.isEmpty
                ? _buildEmptyState(convoProvider.isSearching)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: convoProvider.filteredConversations.length,
                    itemBuilder: (context, index) {
                      final convo = convoProvider.filteredConversations[index];
                      final searchResult = convoProvider.getSearchResultForConversation(convo.id);
                      final isSelected = convo.id == chatProvider.conversationId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: _buildConversationContent(
                            convo,
                            searchResult,
                            convoProvider.searchQuery,
                          ),
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF2A3D47),
                          tileColor: isSelected 
                              ? const Color(0xFF2A3D47)
                              : Colors.transparent,
                          onTap: () async {
                            Navigator.pop(context);
                            _onDrawerClosed(); // Clear search when selecting conversation
                            await chatProvider.loadConversation(convo.id);
                          },
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF141718),
                              builder: (context) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.edit, color: Colors.white),
                                      title: const Text(
                                        'Rename',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        final newTitle = await widget.onRenameDialog(
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
                                      leading: const Icon(Icons.delete, color: Colors.white),
                                      title: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.white),
                                      ),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationContent(
    ConversationSummary conversation,
    SearchResult? searchResult,
    String searchQuery,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Conversation title (always show with highlighting if it matches)
        _buildHighlightedTitle(conversation.title, searchQuery),
        
        // Message snippet (only show if this is a message match)
        if (searchResult?.isMessageMatch == true && searchResult?.messageSnippet != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildHighlightedSnippet(searchResult!.messageSnippet!, searchQuery),
          ),
      ],
    );
  }

  Widget _buildHighlightedTitle(String title, String searchQuery) {
    if (searchQuery.isEmpty) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return _buildHighlightedText(
      title,
      searchQuery,
      const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      1,
    );
  }

  Widget _buildHighlightedSnippet(String snippet, String searchQuery) {
    return _buildHighlightedText(
      snippet,
      searchQuery,
      TextStyle(
        color: Colors.grey.withOpacity(0.8),
        fontSize: 13,
        fontStyle: FontStyle.italic,
      ),
      2,
    );
  }

  Widget _buildHighlightedText(
    String text,
    String searchQuery,
    TextStyle baseStyle,
    int maxLines,
  ) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + searchQuery.length),
            style: baseStyle.copyWith(
              backgroundColor: Colors.yellow,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(index + searchQuery.length)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching 
                  ? 'No conversations found'
                  : 'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try adjusting your search terms'
                  : 'Start a new chat to begin',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
