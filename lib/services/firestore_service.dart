import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/app_user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Map<String, AppUser> _userCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration CACHE_DURATION = Duration(minutes: 5);

  Future<AppUser?> getUserWithCache(String uid) async {
    // Check cache first
    if (_userCache.containsKey(uid)) {
      final cacheTime = _cacheTimestamps[uid];
      if (cacheTime != null && 
          DateTime.now().difference(cacheTime) < CACHE_DURATION) {
        print('✅ Returning cached user data for: $uid');
        return _userCache[uid];
      }
    }

    // Fetch from Firestore
    final stopwatch = Stopwatch()..start();
    try {
      final doc = await _db.collection('users').doc(uid).get();
      stopwatch.stop();
      
      print('📊 Firestore fetch took: ${stopwatch.elapsedMilliseconds}ms');
      
      if (doc.exists && doc.data() != null) {
        final user = AppUser.fromMap(uid, doc.data()!);
        
        // Update cache
        _userCache[uid] = user;
        _cacheTimestamps[uid] = DateTime.now();
        
        return user;
      }
      return null;
    } catch (e) {
      stopwatch.stop();
      print('❌ Error getting user (${stopwatch.elapsedMilliseconds}ms): $e');
      
      // Return cached data if available (graceful degradation)
      return _userCache[uid];
    }
  }

  void clearUserCache(String uid) {
    _userCache.remove(uid);
    _cacheTimestamps.remove(uid);
  }

  // Performance tracking for critical operations:
  Future<T> trackPerformance<T>(
    String operation, 
    Future<T> Function() function
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await function();
      stopwatch.stop();
      print('📊 $operation completed in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ $operation failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Create a new conversation with default title
  Future<String> createConversation(String userId) async {
    return createConversationWithTitle(userId, 'New Chat');
  }

  /// Create a new conversation with a custom title
  Future<String> createConversationWithTitle(
    String userId,
    String title,
  ) async {
    final docRef = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .add({'title': title, 'createdAt': DateTime.now().toIso8601String()});

    return docRef.id;
  }

  /// Save a message to a specific conversation
  Future<void> saveMessage(
    String userId,
    String conversationId,
    ChatMessage message,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
          'text': message.text,
          'sender': message.sender,
          'timestamp': message.timestamp.toIso8601String(),
        });
  }

  /// Get all messages for a specific conversation
  Future<List<ChatMessage>> getMessages(
    String userId,
    String conversationId,
  ) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    return snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList();
  }

  /// Get all conversation summaries (for sidebar list)
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    if (userId.isEmpty) {
      print('❌ Error: userId is empty in getConversations');
      return [];
    }

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'],
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  /// Search conversations by title (server-side search for large datasets)
  Future<List<Map<String, dynamic>>> searchConversations(
    String userId,
    String searchQuery,
  ) async {
    if (searchQuery.trim().isEmpty) {
      return getConversations(userId);
    }

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .where('title', isGreaterThanOrEqualTo: searchQuery)
        .where('title', isLessThan: searchQuery + '\uf8ff')
        .orderBy('title')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'],
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  /// Update a conversation title
  Future<void> updateConversationTitle(
    String userId,
    String conversationId,
    String newTitle,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .update({'title': newTitle});
  }

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(String userId, String conversationId) async {
    final batch = _db.batch();
    final messagesRef = _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');

    final messagesSnapshot = await messagesRef.get();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final convoRef = _db
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId);

    batch.delete(convoRef);
    await batch.commit();
  }

  /// Save AppUser to Firestore (overwrite or merge)
  Future<void> saveUser(AppUser user) async {
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true));
      print('✅ User saved to Firestore: ${user.uid}');
    } catch (e) {
      print('❌ Error saving user: $e');
      rethrow;
    }
  }

  /// Get AppUser from Firestore
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(uid, doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }

  /// Update user subscription status
  Future<void> updateUserSubscription(
    String userId,
    String subscriptionType,
    DateTime expiryDate,
  ) async {
    try {
      await _db.collection('users').doc(userId).update({
        'isPremium': true,
        'subscriptionType': subscriptionType,
        'subscriptionExpiryDate': Timestamp.fromDate(expiryDate),
        'subscriptionStartDate': Timestamp.fromDate(DateTime.now()),
      });
      print('✅ Subscription updated for user: $userId');
    } catch (e) {
      print('❌ Error updating subscription: $e');
      rethrow;
    }
  }

  /// Cancel user subscription (mark as expired)
  Future<void> cancelUserSubscription(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'isPremium': false,
        'subscriptionType': null,
        'subscriptionExpiryDate': null,
      });
      print('✅ Subscription cancelled for user: $userId');
    } catch (e) {
      print('❌ Error cancelling subscription: $e');
      rethrow;
    }
  }

  /// Update user daily usage
  Future<void> updateUserUsage(
    String userId,
    String usageType, // 'messages', 'images', 'voice'
    int count,
  ) async {
    try {
      // Get current user data
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final currentUsage = Map<String, int>.from(userData['dailyUsage'] ?? {});

      // Update the specific usage type
      currentUsage[usageType] = count;

      await _db.collection('users').doc(userId).update({
        'dailyUsage': currentUsage,
        'lastUsageReset': Timestamp.fromDate(DateTime.now()),
      });

      print('✅ Usage updated for user: $userId - $usageType: $count');
    } catch (e) {
      print('❌ Error updating usage: $e');
      rethrow;
    }
  }

  /// Reset daily usage for a user (called at start of new day)
  Future<void> resetUserDailyUsage(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'dailyUsage': {'messages': 0, 'images': 0, 'voice': 0},
        'lastUsageReset': Timestamp.fromDate(DateTime.now()),
      });
      print('✅ Daily usage reset for user: $userId');
    } catch (e) {
      print('❌ Error resetting daily usage: $e');
      rethrow;
    }
  }

  /// Get user's current usage stats
  Future<Map<String, int>> getUserUsage(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return Map<String, int>.from(
          data['dailyUsage'] ?? {'messages': 0, 'images': 0, 'voice': 0},
        );
      }
      return {'messages': 0, 'images': 0, 'voice': 0};
    } catch (e) {
      print('❌ Error getting user usage: $e');
      return {'messages': 0, 'images': 0, 'voice': 0};
    }
  }

  /// Check if user's subscription has expired and update status
  Future<void> checkAndUpdateExpiredSubscriptions() async {
    try {
      final now = DateTime.now();
      final query = await _db
          .collection('users')
          .where('isPremium', isEqualTo: true)
          .where('subscriptionExpiryDate', isLessThan: Timestamp.fromDate(now))
          .get();

      final batch = _db.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {
          'isPremium': false,
          'subscriptionType': null,
        });
      }

      if (query.docs.isNotEmpty) {
        await batch.commit();
        print('✅ Updated ${query.docs.length} expired subscriptions');
      }
    } catch (e) {
      print('❌ Error checking expired subscriptions: $e');
    }
  }

  /// Get subscription analytics (for admin purposes)
  Future<Map<String, dynamic>> getSubscriptionStats() async {
    try {
      final allUsersQuery = await _db.collection('users').get();
      final premiumUsersQuery = await _db
          .collection('users')
          .where('isPremium', isEqualTo: true)
          .get();

      final monthlySubscribers = await _db
          .collection('users')
          .where('subscriptionType', isEqualTo: 'premium_monthly')
          .get();

      final yearlySubscribers = await _db
          .collection('users')
          .where('subscriptionType', isEqualTo: 'premium_yearly')
          .get();

      return {
        'totalUsers': allUsersQuery.size,
        'premiumUsers': premiumUsersQuery.size,
        'monthlySubscribers': monthlySubscribers.size,
        'yearlySubscribers': yearlySubscribers.size,
        'conversionRate': allUsersQuery.size > 0
            ? (premiumUsersQuery.size / allUsersQuery.size * 100)
                  .toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      print('❌ Error getting subscription stats: $e');
      return {};
    }
  }

  // Retry logic for critical operations:

  Future<void> saveUserWithRetry(AppUser user, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _db
            .collection('users')
            .doc(user.uid)
            .set(user.toMap(), SetOptions(merge: true));
        print('✅ User saved to Firestore: ${user.uid}');
        return; // Success
      } catch (e) {
        print('❌ Error saving user (attempt $attempt/$maxRetries): $e');

        if (attempt == maxRetries) {
          // Last attempt failed
          throw Exception('Failed to save user after $maxRetries attempts: $e');
        }

        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  // connection checking utility:
  Future<bool> isConnectedToFirestore() async {
    try {
      await _db.collection('_connection_test').limit(1).get();
      return true;
    } catch (e) {
      print('⚠️ Firestore connection check failed: $e');
      return false;
    }
  }
}
