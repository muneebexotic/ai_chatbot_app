import 'package:flutter/material.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../models/chat_message.dart';

class ConversationSummary {
  final String id;
  String title;
  final String createdAt;

  ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
  });
}

class SearchResult {
  final ConversationSummary conversation;
  final String? messageSnippet;
  final bool isMessageMatch;

  SearchResult({
    required this.conversation,
    this.messageSnippet,
    this.isMessageMatch = false,
  });
}

class ConversationsProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  String _userId;
  String get userId => _userId;
  
  List<ConversationSummary> _conversations = [];
  List<SearchResult> _searchResults = [];
  String _searchQuery = '';
  bool _isSearching = false;
  Timer? _debounceTimer;

  ConversationsProvider({required String userId}) : _userId = userId {
    if (_userId.isNotEmpty) {
      loadConversations();
    }
  }

  // Update userId when user changes (for provider proxy)
  void updateUserId(String newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      _conversations.clear(); // Clear old conversations
      _searchResults.clear();
      _searchQuery = '';
      _isSearching = false;
      _debounceTimer?.cancel();
      
      if (newUserId.isNotEmpty) {
        loadConversations(); // Load conversations for new user
      } else {
        notifyListeners(); // Notify listeners of cleared state
      }
    }
  }

  List<ConversationSummary> get conversations => _conversations;
  List<SearchResult> get searchResults => _searchResults;
  List<ConversationSummary> get filteredConversations => 
      _isSearching ? _searchResults.map((r) => r.conversation).toList() : _conversations;
  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;

  Future<void> loadConversations() async {
    if (_userId.isEmpty) {
      print('❌ Cannot load conversations: userId is empty');
      return;
    }

    try {
      print('📂 Loading conversations for user: $_userId');
      final data = await _firestoreService.getConversations(_userId);
      _conversations = data.map((map) {
        return ConversationSummary(
          id: map['id'],
          title: map['title'],
          createdAt: map['createdAt'],
        );
      }).toList();
      
      print('✅ Loaded ${_conversations.length} conversations');
      
      // Update search results if search is active
      if (_isSearching) {
        await _performSearch(_searchQuery);
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading conversations: $e');
      _conversations = [];
      notifyListeners();
    }
  }

  void searchConversations(String query) {
    _searchQuery = query;
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Set up debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().isEmpty) {
        _isSearching = false;
        _searchResults.clear();
      } else {
        _isSearching = true;
        await _performSearch(query);
      }
      notifyListeners();
    });
  }

  Future<void> _performSearch(String query) async {
    if (_userId.isEmpty) return;

    final lowerQuery = query.toLowerCase().trim();
    _searchResults.clear();

    // Step 1: Search conversation titles
    final titleMatches = _conversations.where((conversation) {
      return conversation.title.toLowerCase().contains(lowerQuery);
    }).map((conv) => SearchResult(conversation: conv, isMessageMatch: false)).toList();

    // Step 2: Search message content
    final messageMatches = <SearchResult>[];
    
    for (final conversation in _conversations) {
      // Skip if already matched by title
      if (titleMatches.any((match) => match.conversation.id == conversation.id)) {
        continue;
      }
      
      try {
        final messages = await _firestoreService.getMessages(_userId, conversation.id);
        
        for (final message in messages) {
          if (message.text.toLowerCase().contains(lowerQuery)) {
            final snippet = _generateSnippet(message.text, lowerQuery);
            messageMatches.add(SearchResult(
              conversation: conversation,
              messageSnippet: snippet,
              isMessageMatch: true,
            ));
            break; // Only take first matching message per conversation
          }
        }
      } catch (e) {
        debugPrint('Error searching messages for conversation ${conversation.id}: $e');
      }
    }

    // Combine and sort results (title matches first, then message matches)
    _searchResults = [...titleMatches, ...messageMatches];
    
    // Sort title matches by relevance
    _searchResults.sort((a, b) {
      // Title matches always come before message matches
      if (a.isMessageMatch != b.isMessageMatch) {
        return a.isMessageMatch ? 1 : -1;
      }
      
      if (!a.isMessageMatch && !b.isMessageMatch) {
        // Both are title matches - sort by relevance
        final aTitle = a.conversation.title.toLowerCase();
        final bTitle = b.conversation.title.toLowerCase();
        
        // Exact matches first
        if (aTitle == lowerQuery && bTitle != lowerQuery) return -1;
        if (bTitle == lowerQuery && aTitle != lowerQuery) return 1;
        
        // Then by how early the match appears
        final aIndex = aTitle.indexOf(lowerQuery);
        final bIndex = bTitle.indexOf(lowerQuery);
        
        if (aIndex != bIndex) return aIndex.compareTo(bIndex);
        
        // Finally by title length (shorter titles first)
        return aTitle.length.compareTo(bTitle.length);
      }
      
      // Both are message matches - keep original order
      return 0;
    });
  }

  String _generateSnippet(String messageText, String query) {
    const snippetLength = 100;
    const contextWords = 20;
    
    final lowerText = messageText.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final queryIndex = lowerText.indexOf(lowerQuery);
    
    if (queryIndex == -1) return messageText;
    
    // Calculate snippet boundaries
    int start = (queryIndex - contextWords).clamp(0, messageText.length);
    int end = (queryIndex + query.length + contextWords).clamp(0, messageText.length);
    
    // Adjust to word boundaries when possible
    if (start > 0) {
      final spaceIndex = messageText.indexOf(' ', start);
      if (spaceIndex != -1 && spaceIndex - start < 10) {
        start = spaceIndex + 1;
      }
    }
    
    if (end < messageText.length) {
      final spaceIndex = messageText.lastIndexOf(' ', end);
      if (spaceIndex != -1 && end - spaceIndex < 10) {
        end = spaceIndex;
      }
    }
    
    String snippet = messageText.substring(start, end);
    
    // Add ellipsis if needed
    if (start > 0) snippet = '...$snippet';
    if (end < messageText.length) snippet = '$snippet...';
    
    return snippet;
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _searchQuery = '';
    _isSearching = false;
    _searchResults.clear();
    notifyListeners();
  }

  // Helper method to get search result for a conversation
  SearchResult? getSearchResultForConversation(String conversationId) {
    if (!_isSearching) return null;
    try {
      return _searchResults.firstWhere((result) => result.conversation.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  Future<void> addConversation(String title) async {
    if (_userId.isEmpty) return;

    try {
      final id = await _firestoreService.createConversationWithTitle(_userId, title);
      _conversations.insert(
        0,
        ConversationSummary(id: id, title: title, createdAt: DateTime.now().toIso8601String()),
      );
      
      // Update search results if search is active
      if (_isSearching) {
        await _performSearch(_searchQuery);
      }
      
      notifyListeners();
      print('✅ Conversation added: $title');
    } catch (e) {
      print('❌ Error adding conversation: $e');
      rethrow;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    if (_userId.isEmpty) return;

    try {
      await _firestoreService.deleteConversation(_userId, conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      
      // Update search results if search is active
      if (_isSearching) {
        _searchResults.removeWhere((r) => r.conversation.id == conversationId);
      }
      
      notifyListeners();
      print('✅ Conversation deleted: $conversationId');
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  Future<void> renameConversation(String conversationId, String newTitle) async {
    if (_userId.isEmpty) return;

    try {
      final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
      if (convoIndex != -1) {
        _conversations[convoIndex].title = newTitle;
        
        // Update in Firestore
        await _firestoreService.updateConversationTitle(_userId, conversationId, newTitle);
        
        // Update search results if search is active
        if (_isSearching) {
          await _performSearch(_searchQuery);
        }
        
        notifyListeners();
        print('✅ Conversation renamed: $conversationId -> $newTitle');
      }
    } catch (e) {
      print('❌ Error renaming conversation: $e');
      rethrow;
    }
  }

  // Clear conversations when user logs out
  void clearConversations() {
    _conversations.clear();
    _searchResults.clear();
    _searchQuery = '';
    _isSearching = false;
    _debounceTimer?.cancel();
    notifyListeners();
  }

  // Refresh conversations (useful after creating new conversation)
  Future<void> refreshConversations() async {
    await loadConversations();
  }

  // Get conversation by ID
  ConversationSummary? getConversationById(String conversationId) {
    try {
      return _conversations.firstWhere((conv) => conv.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  // Check if a conversation exists
  bool hasConversation(String conversationId) {
    return _conversations.any((conv) => conv.id == conversationId);
  }

  // Get conversation count
  int get conversationCount => _conversations.length;

  // Get recent conversations (first 5)
  List<ConversationSummary> get recentConversations {
    return _conversations.take(5).toList();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}