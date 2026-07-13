import 'package:flutter/material.dart';

import '../models/mini_app_model.dart';
import '../services/social_friend_service.dart';
import '../widgets/layout/telegram_chat_list.dart';
import '../widgets/layout/telegram_drawer.dart';
import '../widgets/layout/telegram_split_view.dart';
import '../widgets/social/social_feature_bot.dart';
import '../widgets/space_background.dart';
import 'social_feature_chat_screen.dart';
import 'telegram_friend_chat_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late SocialFeatureBot _selectedBot;
  SocialFriendContact? _selectedFriend;

  @override
  void initState() {
    super.initState();
    _selectedBot = _initialBotFromUrl();
    _applyInitialBotFromUrl();
  }

  SocialFeatureBot _initialBotFromUrl() {
    final defaults = defaultSocialMiniAppBots();
    final tab = Uri.base.queryParameters['tab']?.toLowerCase();
    final kind = switch (tab) {
      'flashcards' || 'cards' || 'beisong' => MiniAppBotKind.flashcards,
      'publish' ||
      'platform' ||
      'platform-publish' => MiniAppBotKind.platformPublish,
      'father' || 'botfather' || 'bot-father' => MiniAppBotKind.botFather,
      _ => MiniAppBotKind.globalDharma,
    };
    return defaults.firstWhere(
      (bot) => bot.effectiveKind == kind,
      orElse: () => defaults.first,
    );
  }

  void _applyInitialBotFromUrl() {
    _selectedBot = _initialBotFromUrl();
  }

  void _handleBotSelected(SocialFeatureBot bot, bool isNarrow) {
    setState(() {
      _selectedBot = bot;
      _selectedFriend = null;
    });
    if (isNarrow) {
      // In narrow (Mobile) mode, push the chat view onto the navigator stack.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(
              0xFF0E1621,
            ), // Telegram dark theme chat bg
            body: SocialFeatureChatScreen(bot: bot),
          ),
        ),
      );
    }
  }

  void _handleFriendSelected(SocialFriendContact friend, bool isNarrow) {
    setState(() => _selectedFriend = friend);
    if (isNarrow) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF0E1621),
            body: TelegramFriendChatScreen(friend: friend),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          return Scaffold(
            backgroundColor: Colors.transparent,
            drawer: const TelegramDrawer(),
            body: isNarrow ? _buildNarrowShell() : _buildWideShell(),
          );
        },
      ),
    );
  }

  Widget _buildNarrowShell() {
    return TelegramChatList(
      selectedBot: _selectedBot.stableBotId,
      onBotSelected: (bot) => _handleBotSelected(bot, true),
      onFriendSelected: (friend) => _handleFriendSelected(friend, true),
      selectedFriendId: _selectedFriend?.id,
      isMobile: true,
    );
  }

  Widget _buildWideShell() {
    return TelegramSplitView(
      leftMenu: TelegramChatList(
        selectedBot: _selectedBot.stableBotId,
        onBotSelected: (bot) => _handleBotSelected(bot, false),
        onFriendSelected: (friend) => _handleFriendSelected(friend, false),
        selectedFriendId: _selectedFriend?.id,
        isMobile: false,
      ),
      rightContent: _selectedFriend == null
          ? SocialFeatureChatScreen(bot: _selectedBot)
          : TelegramFriendChatScreen(friend: _selectedFriend!),
    );
  }
}
