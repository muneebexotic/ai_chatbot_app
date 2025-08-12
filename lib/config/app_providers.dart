// MultiProvider setup

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/themes_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/settings_provider.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(
      create: (_) {
        final settingsProvider = SettingsProvider();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          settingsProvider.initializeSettings();
        });
        return settingsProvider;
      },
    ),

    ChangeNotifierProxyProvider<AuthProvider, SubscriptionProvider>(
      create: (context) {
        final authProvider = context.read<AuthProvider>();
        return SubscriptionProvider(authProvider.paymentService);
      },
      update: (_, authProvider, subscriptionProvider) {
        if (subscriptionProvider != null) {
          return subscriptionProvider;
        }
        return SubscriptionProvider(authProvider.paymentService);
      },
    ),

    ChangeNotifierProxyProvider<AuthProvider, ConversationsProvider>(
      create: (_) => ConversationsProvider(userId: ''),
      update: (_, auth, previous) {
        final userId = auth.user?.uid ?? '';
        if (previous?.userId != userId) {
          return ConversationsProvider(userId: userId);
        }
        previous?.updateUserId(userId);
        return previous ?? ConversationsProvider(userId: userId);
      },
    ),
    ChangeNotifierProxyProvider2<AuthProvider, SettingsProvider, ChatProvider>(
      create: (context) => ChatProvider(userId: '', context: context),
      update: (context, auth, settings, previous) {
        final userId = auth.user?.uid ?? '';
        if (previous?.userId != userId) {
          return ChatProvider(userId: userId, context: context);
        }
        return previous ?? ChatProvider(userId: userId, context: context);
      },
    ),
  ];
}
