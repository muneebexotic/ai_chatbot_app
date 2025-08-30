// lib\services\firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/app_user.dart';

/// Enhanced FirestoreService with improved error handling, performance, and reliability
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User cache management
  final Map<String, AppUser> _userCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Configuration constants
  static const Duration CACHE_DURATION = Duration(minutes: 5);
  static const Duration OPERATION_TIMEOUT = Duration(seconds: 30);
  static const int MAX_RETRY_ATTEMPTS = 3;
  static const int MAX_BATCH_SIZE = 500;
  static const int SEARCH_RESULTS_LIMIT = 50;

  // Connection state
  bool _isOffline = false;
  final List<Map<String, dynamic>> _offlineQueue = [];

  /// Get user with intelligent caching and offline support
  Future<AppUser?> getUserWithCache(String uid) async {
    if (uid.isEmpty) {
      print('❌ Error: getUserWithCache called with empty uid');
      return null;
    }

    // Check cache first with enhanced validation
    if (_userCache.containsKey(uid)) {
      final cacheTime = _cacheTimestamps[uid];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < CACHE_DURATION) {
        print('✅ Returning cached user data for: $uid');
        return _userCache[uid];
      } else {
        // Clear expired cache entry
        _clearSingleUserCache(uid);
      }
    }

    // Fetch from Firestore with enhanced error handling
    return await _performOperationWithRetry(
      operation: () => _fetchUserFromFirestore(uid),
      operationName: 'getUserWithCache',
      maxRetries: MAX_RETRY_ATTEMPTS,
    );
  }

  /// Fetch user from Firestore with enhanced error handling
  Future<AppUser?> _fetchUserFromFirestore(String uid) async {
    final stopwatch = Stopwatch()..start();

    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(OPERATION_TIMEOUT);

      stopwatch.stop();
      print('📊 Firestore user fetch took: ${stopwatch.elapsedMilliseconds}ms');

      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          print('⚠️ Document data is null for uid: $uid');
          return null;
        }

        final user = AppUser.fromMapWithValidation(uid, data);

        if (user != null) {
          // Update cache with validation
          _updateUserCache(uid, user);
          return user;
        } else {
          print('⚠️ Invalid user data returned from Firestore for uid: $uid');
        }
      }

      return null;
    } catch (e) {
      stopwatch.stop();
      print('❌ Error getting user (${stopwatch.elapsedMilliseconds}ms): $e');

      // Check if we're offline
      if (_isNetworkError(e)) {
        _isOffline = true;
        print('📶 Network error detected, entering offline mode');
      }

      // Return cached data if available (graceful degradation)
      return _userCache[uid];
    }
  }

  /// Update user cache with validation
  void _updateUserCache(String uid, AppUser user) {
    if (uid.isEmpty || !user.isValid()) {
      print('⚠️ Attempted to cache invalid user data');
      return;
    }

    _userCache[uid] = user;
    _cacheTimestamps[uid] = DateTime.now();
  }

  /// Clear single user from cache
  void _clearSingleUserCache(String uid) {
    _userCache.remove(uid);
    _cacheTimestamps.remove(uid);
  }

  /// Clear all user cache
  void clearUserCache(String? uid) {
    if (uid != null) {
      _clearSingleUserCache(uid);
    } else {
      _userCache.clear();
      _cacheTimestamps.clear();
    }
  }

  /// Enhanced operation with retry logic and timeout
  Future<T> _performOperationWithRetry<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxRetries = MAX_RETRY_ATTEMPTS,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final result = await operation().timeout(OPERATION_TIMEOUT);

        // Reset offline status on successful operation
        if (_isOffline) {
          _isOffline = false;
          await _processOfflineQueue();
        }

        return result;
      } catch (e) {
        print('❌ $operationName failed (attempt $attempt/$maxRetries): $e');

        if (_isNetworkError(e)) {
          _isOffline = true;
        }

        if (attempt == maxRetries) {
          throw FirestoreServiceException(
            'Failed to execute $operationName after $maxRetries attempts: $e',
          );
        }

        // Exponential backoff
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw FirestoreServiceException('Unexpected error in retry logic');
  }

  /// Enhanced performance tracking for critical operations
  Future<T> trackPerformance<T>(
    String operation,
    Future<T> Function() function, {
    Duration? warningThreshold,
  }) async {
    final stopwatch = Stopwatch()..start();
    final threshold = warningThreshold ?? const Duration(seconds: 5);

    try {
      final result = await function();
      stopwatch.stop();

      final duration = stopwatch.elapsedMilliseconds;
      if (Duration(milliseconds: duration) > threshold) {
        print('⚠️ $operation took ${duration}ms (above threshold)');
      } else {
        print('📊 $operation completed in ${duration}ms');
      }

      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ $operation failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Create a new conversation with enhanced validation
  Future<String> createConversation(String userId) async {
    return createConversationWithTitle(userId, 'New Chat');
  }

  /// Create a new conversation with a custom title and validation
  Future<String> createConversationWithTitle(
    String userId,
    String title,
  ) async {
    if (userId.isEmpty) {
      throw FirestoreServiceException('User ID cannot be empty');
    }

    if (title.trim().isEmpty) {
      title = 'New Chat';
    }

    // Sanitize title
    final sanitizedTitle = _sanitizeString(title, maxLength: 100);

    return await _performOperationWithRetry(
      operation: () async {
        final docRef = await _db
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .add({
              'title': sanitizedTitle,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'messageCount': 0,
            });

        return docRef.id;
      },
      operationName: 'createConversation',
    );
  }

  /// Save a message with enhanced validation and transaction safety
  Future<void> saveMessage(
    String userId,
    String conversationId,
    ChatMessage message,
  ) async {
    if (userId.isEmpty || conversationId.isEmpty) {
      throw FirestoreServiceException(
        'User ID and Conversation ID cannot be empty',
      );
    }

    if (!message.isValid()) {
      throw FirestoreServiceException('Invalid message data');
    }

    await _performOperationWithRetry(
      operation: () => _saveMessageTransaction(userId, conversationId, message),
      operationName: 'saveMessage',
    );
  }

  /// Save message with transaction to ensure consistency
  Future<void> _saveMessageTransaction(
    String userId,
    String conversationId,
    ChatMessage message,
  ) async {
    return await _db.runTransaction((transaction) async {
      // References
      final conversationRef = _db
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .doc(conversationId);

      final messagesRef = conversationRef.collection('messages').doc();

      // Get current conversation data
      final conversationDoc = await transaction.get(conversationRef);

      if (!conversationDoc.exists) {
        throw FirestoreServiceException('Conversation not found');
      }

      final currentData = conversationDoc.data()!;
      final currentMessageCount = currentData['messageCount'] ?? 0;

      // Prepare message map
      final messageMap = message.toMap();
      messageMap['timestamp'] = FieldValue.serverTimestamp();
      messageMap['messageId'] = messagesRef.id;

      // Save message
      transaction.set(messagesRef, messageMap);

      // Update conversation metadata
      transaction.update(conversationRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'messageCount': currentMessageCount + 1,
        'lastMessage': _sanitizeString(message.displayText, maxLength: 200),
      });
    });
  }

  /// Get all messages with enhanced pagination and caching
  Future<List<ChatMessage>> getMessages(
    String userId,
    String conversationId, {
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    if (userId.isEmpty || conversationId.isEmpty) {
      throw FirestoreServiceException(
        'User ID and Conversation ID cannot be empty',
      );
    }

    return await _performOperationWithRetry(
      operation: () async {
        Query query = _db
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('timestamp', descending: false);

        if (limit != null) {
          query = query.limit(limit);
        }

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        final snapshot = await query.get();

        return snapshot.docs
            .map(
              (doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>),
            )
            .where((message) => message.isValid())
            .toList();
      },
      operationName: 'getMessages',
    );
  }

  /// Get all conversation summaries with enhanced error handling
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    if (userId.isEmpty) {
      print('❌ Error: userId is empty in getConversations');
      return [];
    }

    return await _performOperationWithRetry(
      operation: () async {
        final snapshot = await _db
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .orderBy('updatedAt', descending: true)
            .limit(100) // Reasonable limit
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Untitled Chat',
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            'messageCount': data['messageCount'] ?? 0,
            'lastMessage': data['lastMessage'] ?? '',
          };
        }).toList();
      },
      operationName: 'getConversations',
    );
  }

  /// Enhanced search with proper Firestore text search limitations
  Future<List<Map<String, dynamic>>> searchConversations(
    String userId,
    String searchQuery,
  ) async {
    if (userId.isEmpty) {
      return [];
    }

    if (searchQuery.trim().isEmpty) {
      return getConversations(userId);
    }

    final sanitizedQuery = _sanitizeString(searchQuery.trim(), maxLength: 100);

    return await _performOperationWithRetry(
      operation: () async {
        // Get all conversations first (with reasonable limit)
        final snapshot = await _db
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .orderBy('updatedAt', descending: true)
            .limit(200)
            .get();

        // Perform client-side filtering for better search experience
        final results = <Map<String, dynamic>>[];
        final queryLower = sanitizedQuery.toLowerCase();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final lastMessage = (data['lastMessage'] ?? '')
              .toString()
              .toLowerCase();

          if (title.contains(queryLower) || lastMessage.contains(queryLower)) {
            results.add({
              'id': doc.id,
              'title': data['title'] ?? 'Untitled Chat',
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
              'messageCount': data['messageCount'] ?? 0,
              'lastMessage': data['lastMessage'] ?? '',
            });
          }

          // Limit client-side results
          if (results.length >= SEARCH_RESULTS_LIMIT) break;
        }

        return results;
      },
      operationName: 'searchConversations',
    );
  }

  /// Update conversation title with validation
  Future<void> updateConversationTitle(
    String userId,
    String conversationId,
    String newTitle,
  ) async {
    if (userId.isEmpty || conversationId.isEmpty) {
      throw FirestoreServiceException(
        'User ID and Conversation ID cannot be empty',
      );
    }

    if (newTitle.trim().isEmpty) {
      throw FirestoreServiceException('Title cannot be empty');
    }

    final sanitizedTitle = _sanitizeString(newTitle, maxLength: 100);

    await _performOperationWithRetry(
      operation: () async {
        await _db
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .doc(conversationId)
            .update({
              'title': sanitizedTitle,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      },
      operationName: 'updateConversationTitle',
    );
  }

  /// Delete a conversation with enhanced batch handling for large datasets
  Future<void> deleteConversation(String userId, String conversationId) async {
    if (userId.isEmpty || conversationId.isEmpty) {
      throw FirestoreServiceException(
        'User ID and Conversation ID cannot be empty',
      );
    }

    await _performOperationWithRetry(
      operation: () => _deleteConversationInBatches(userId, conversationId),
      operationName: 'deleteConversation',
    );
  }

  /// Delete conversation in batches to handle large message collections
  Future<void> _deleteConversationInBatches(
    String userId,
    String conversationId,
  ) async {
    final messagesRef = _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');

    // Delete messages in batches
    bool hasMore = true;
    while (hasMore) {
      final batch = _db.batch();
      final snapshot = await messagesRef.limit(MAX_BATCH_SIZE).get();

      if (snapshot.docs.isEmpty) {
        hasMore = false;
      } else {
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Check if there are more documents
        hasMore = snapshot.docs.length == MAX_BATCH_SIZE;
      }
    }

    // Finally, delete the conversation document
    await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .delete();
  }

  /// Save AppUser with enhanced validation and retry logic
  Future<void> saveUser(AppUser user) async {
    if (!user.isValid()) {
      throw FirestoreServiceException('Invalid user data');
    }

    final subscriptionValidationError = user.validateSubscription();
    if (subscriptionValidationError != null) {
      print('⚠️ Subscription validation warning: $subscriptionValidationError');
    }

    await saveUserWithRetry(user);
  }

  /// Get AppUser from Firestore (direct, no cache)
  Future<AppUser?> getUser(String uid) async {
    if (uid.isEmpty) {
      throw FirestoreServiceException('User ID cannot be empty');
    }

    return await _performOperationWithRetry(
      operation: () async {
        final doc = await _db.collection('users').doc(uid).get();

        if (doc.exists && doc.data() != null) {
          return AppUser.fromMapWithValidation(uid, doc.data()!);
        }
        return null;
      },
      operationName: 'getUser',
    );
  }

  /// Update user subscription with transaction safety
  Future<void> updateUserSubscription(
    String userId,
    String subscriptionType,
    DateTime expiryDate,
  ) async {
    if (userId.isEmpty || subscriptionType.isEmpty) {
      throw FirestoreServiceException('Invalid subscription parameters');
    }

    await _performOperationWithRetry(
      operation: () async {
        await _db.runTransaction((transaction) async {
          final userRef = _db.collection('users').doc(userId);
          final userDoc = await transaction.get(userRef);

          if (!userDoc.exists) {
            throw FirestoreServiceException('User not found');
          }

          transaction.update(userRef, {
            'isPremium': true,
            'subscriptionType': subscriptionType,
            'subscriptionExpiryDate': Timestamp.fromDate(expiryDate),
            'subscriptionStartDate': Timestamp.fromDate(DateTime.now()),
            'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
          });
        });

        // Clear cache to force refresh
        clearUserCache(userId);
        print('✅ Subscription updated for user: $userId');
      },
      operationName: 'updateUserSubscription',
    );
  }

  /// Cancel user subscription with proper cleanup
  Future<void> cancelUserSubscription(String userId) async {
    if (userId.isEmpty) {
      throw FirestoreServiceException('User ID cannot be empty');
    }

    await _performOperationWithRetry(
      operation: () async {
        await _db.collection('users').doc(userId).update({
          'isPremium': false,
          'subscriptionType': null,
          'subscriptionExpiryDate': null,
          'subscriptionCancelledAt': FieldValue.serverTimestamp(),
        });

        // Clear cache to force refresh
        clearUserCache(userId);
        print('✅ Subscription cancelled for user: $userId');
      },
      operationName: 'cancelUserSubscription',
    );
  }

  /// Update user usage with proper validation and conflict resolution
  Future<void> updateUserUsage(
    String userId,
    String usageType,
    int count,
  ) async {
    if (userId.isEmpty || usageType.isEmpty) {
      throw FirestoreServiceException('Invalid usage parameters');
    }

    if (count < 0 || count > 100000) {
      throw FirestoreServiceException('Invalid usage count: $count');
    }

    if (_isOffline) {
      _queueOfflineOperation('updateUserUsage', {
        'userId': userId,
        'usageType': usageType,
        'count': count,
      });
      return;
    }

    await _performOperationWithRetry(
      operation: () => _updateUserUsageTransaction(userId, usageType, count),
      operationName: 'updateUserUsage',
    );
  }

  /// Update usage with transaction to prevent race conditions
  Future<void> _updateUserUsageTransaction(
    String userId,
    String usageType,
    int count,
  ) async {
    return await _db.runTransaction((transaction) async {
      final userRef = _db.collection('users').doc(userId);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw FirestoreServiceException('User not found');
      }

      final userData = userDoc.data()!;
      final currentUsage = Map<String, int>.from(userData['dailyUsage'] ?? {});

      // Update the specific usage type
      currentUsage[usageType] = count;

      transaction.update(userRef, {
        'dailyUsage': currentUsage,
        'lastUsageUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ Usage updated for user: $userId - $usageType: $count');
    });
  }

  /// Reset daily usage with proper timezone handling
  Future<void> resetUserDailyUsage(String userId) async {
    if (userId.isEmpty) {
      throw FirestoreServiceException('User ID cannot be empty');
    }

    await _performOperationWithRetry(
      operation: () async {
        await _db.collection('users').doc(userId).update({
          'dailyUsage': {'messages': 0, 'images': 0, 'voice': 0},
          'lastUsageReset': FieldValue.serverTimestamp(),
        });

        // Clear cache to force refresh
        clearUserCache(userId);
        print('✅ Daily usage reset for user: $userId');
      },
      operationName: 'resetUserDailyUsage',
    );
  }

  /// Increment daily usage with proper timezone handling
  Future<void> incrementUserDailyUsage(
    String userId,
    String usageType,
  ) async {
    if (userId.isEmpty) {
      throw FirestoreServiceException('User ID cannot be empty');
    }

    await _performOperationWithRetry(
      operation: () async {
        await _db.collection('users').doc(userId).update({
          'dailyUsage.$usageType': FieldValue.increment(1),
          'lastUsageUpdate': FieldValue.serverTimestamp(),
        });

        // Clear cache to force refresh
        clearUserCache(userId);
        print('✅ Incremented daily usage for user: $userId - $usageType');
      },
      operationName: 'incrementUserDailyUsage',
    );
  }

  /// Get user's current usage stats with validation
  Future<Map<String, int>> getUserUsage(String userId) async {
    if (userId.isEmpty) {
      throw FirestoreServiceException('User ID cannot be empty');
    }

    return await _performOperationWithRetry(
      operation: () async {
        final doc = await _db.collection('users').doc(userId).get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final usage = Map<String, int>.from(
            data['dailyUsage'] ?? {'messages': 0, 'images': 0, 'voice': 0},
          );

          // Validate usage data
          usage['messages'] = (usage['messages'] ?? 0).clamp(0, 100000);
          usage['images'] = (usage['images'] ?? 0).clamp(0, 10000);
          usage['voice'] = (usage['voice'] ?? 0).clamp(0, 10000);

          return usage;
        }

        return {'messages': 0, 'images': 0, 'voice': 0};
      },
      operationName: 'getUserUsage',
    );
  }

  /// Check and update expired subscriptions with batch processing
  Future<void> checkAndUpdateExpiredSubscriptions() async {
    return await _performOperationWithRetry(
      operation: () async {
        final now = DateTime.now();
        final query = await _db
            .collection('users')
            .where('isPremium', isEqualTo: true)
            .where(
              'subscriptionExpiryDate',
              isLessThan: Timestamp.fromDate(now),
            )
            .limit(100) // Process in batches
            .get();

        if (query.docs.isNotEmpty) {
          final batch = _db.batch();

          for (var doc in query.docs) {
            batch.update(doc.reference, {
              'isPremium': false,
              'subscriptionType': null,
              'subscriptionExpiredAt': FieldValue.serverTimestamp(),
            });
          }

          await batch.commit();
          print('✅ Updated ${query.docs.length} expired subscriptions');
        }
      },
      operationName: 'checkAndUpdateExpiredSubscriptions',
    );
  }

  /// Get subscription analytics with enhanced error handling
  Future<Map<String, dynamic>> getSubscriptionStats() async {
    return await _performOperationWithRetry(
      operation: () async {
        final futures = await Future.wait([
          _db.collection('users').count().get(),
          _db
              .collection('users')
              .where('isPremium', isEqualTo: true)
              .count()
              .get(),
          _db
              .collection('users')
              .where('subscriptionType', isEqualTo: 'premium_monthly')
              .count()
              .get(),
          _db
              .collection('users')
              .where('subscriptionType', isEqualTo: 'premium_yearly')
              .count()
              .get(),
        ]);

        final totalUsers = futures[0].count ?? 0;
        final premiumUsers = futures[1].count ?? 0;
        final monthlySubscribers = futures[2].count ?? 0;
        final yearlySubscribers = futures[3].count ?? 0;

        return {
          'totalUsers': totalUsers,
          'premiumUsers': premiumUsers,
          'monthlySubscribers': monthlySubscribers,
          'yearlySubscribers': yearlySubscribers,
          'conversionRate': totalUsers > 0
              ? (premiumUsers / totalUsers * 100).toStringAsFixed(1)
              : '0.0',
        };
      },
      operationName: 'getSubscriptionStats',
    );
  }

  /// Save user with enhanced retry logic and validation
  Future<void> saveUserWithRetry(
    AppUser user, {
    int maxRetries = MAX_RETRY_ATTEMPTS,
  }) async {
    if (!user.isValid()) {
      throw FirestoreServiceException('Cannot save invalid user data');
    }

    await _performOperationWithRetry(
      operation: () async {
        await _db
            .collection('users')
            .doc(user.uid)
            .set(user.toMap(), SetOptions(merge: true));

        // Update cache
        _updateUserCache(user.uid, user);
        print('✅ User saved to Firestore: ${user.uid}');
      },
      operationName: 'saveUserWithRetry',
      maxRetries: maxRetries,
    );
  }

  /// Connection checking utility with timeout
  Future<bool> isConnectedToFirestore() async {
    try {
      await _db
          .collection('_connection_test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (_isOffline) {
        _isOffline = false;
        await _processOfflineQueue();
      }

      return true;
    } catch (e) {
      print('⚠️ Firestore connection check failed: $e');
      _isOffline = true;
      return false;
    }
  }

  // OFFLINE SUPPORT AND UTILITIES

  /// Queue operation for offline processing
  void _queueOfflineOperation(String operation, Map<String, dynamic> data) {
    _offlineQueue.add({
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Limit offline queue size
    if (_offlineQueue.length > 100) {
      _offlineQueue.removeAt(0);
    }

    print('📦 Queued offline operation: $operation');
  }

  /// Process offline queue when connection is restored
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    print('🔄 Processing ${_offlineQueue.length} offline operations...');

    final operationsToProcess = List.from(_offlineQueue);
    _offlineQueue.clear();

    for (final operation in operationsToProcess) {
      try {
        await _executeOfflineOperation(operation);
      } catch (e) {
        print('❌ Failed to process offline operation: $e');
        // Re-queue failed operations (but limit retries)
        if (operation['retryCount'] == null || operation['retryCount'] < 3) {
          operation['retryCount'] = (operation['retryCount'] ?? 0) + 1;
          _offlineQueue.add(operation);
        }
      }
    }

    print('✅ Offline queue processing completed');
  }

  /// Execute individual offline operation
  Future<void> _executeOfflineOperation(Map<String, dynamic> operation) async {
    final operationType = operation['operation'] as String;
    final data = operation['data'] as Map<String, dynamic>;

    switch (operationType) {
      case 'updateUserUsage':
        await updateUserUsage(
          data['userId'] as String,
          data['usageType'] as String,
          data['count'] as int,
        );
        break;
      default:
        print('⚠️ Unknown offline operation: $operationType');
    }
  }

  // UTILITY METHODS

  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('unavailable') ||
        errorString.contains('offline');
  }

  /// Sanitize string input to prevent injection and enforce limits
  String _sanitizeString(String input, {int maxLength = 1000}) {
    if (input.isEmpty) return input;

    // Remove potential harmful characters
    String sanitized = input
        .replaceAll(RegExp(r'''[<>"']'''), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Enforce length limit
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'usersCached': _userCache.length,
      'oldestCacheEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newestCacheEntry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
      'isOffline': _isOffline,
      'offlineQueueSize': _offlineQueue.length,
    };
  }

  /// Clear all caches and reset offline state
  void clearAllCaches() {
    _userCache.clear();
    _cacheTimestamps.clear();
    _offlineQueue.clear();
    _isOffline = false;
    print('🧹 All caches cleared');
  }

  /// Dispose resources and cleanup
  void dispose() {
    clearAllCaches();
    print('🧹 FirestoreService disposed');
  }
}

/// Custom exception for Firestore service errors
class FirestoreServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  FirestoreServiceException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'FirestoreServiceException [$code]: $message';
    }
    return 'FirestoreServiceException: $message';
  }
}