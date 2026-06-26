import 'package:flutter/material.dart';

import '../models/mini_app_model.dart';
import '../widgets/layout/telegram_chat_list.dart';
import '../widgets/layout/telegram_drawer.dart';
import '../widgets/layout/telegram_split_view.dart';
import '../widgets/social/social_feature_bot.dart';
import '../widgets/space_background.dart';
import 'social_feature_chat_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late SocialFeatureBot _selectedBot;

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
      isMobile: true,
    );
  }

  Widget _buildWideShell() {
    return TelegramSplitView(
      leftMenu: TelegramChatList(
        selectedBot: _selectedBot.stableBotId,
        onBotSelected: (bot) => _handleBotSelected(bot, false),
        isMobile: false,
      ),
      rightContent: SocialFeatureChatScreen(bot: _selectedBot),
    );
  }
}
