import 'package:flutter/material.dart';

import '../widgets/layout/telegram_chat_list.dart';
import '../widgets/layout/telegram_drawer.dart';
import '../widgets/social/social_feature_bot.dart';
import '../widgets/space_background.dart';
import 'social_feature_chat_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  SocialFeatureBotType _selectedBot = SocialFeatureBotType.globalDharma;

  @override
  void initState() {
    super.initState();
    _applyInitialBotFromUrl();
  }

  void _applyInitialBotFromUrl() {
    final tab = Uri.base.queryParameters['tab']?.toLowerCase();
    _selectedBot = switch (tab) {
      'flashcards' || 'cards' || 'beisong' => SocialFeatureBotType.flashcards,
      'publish' || 'platform' || 'platform-publish' =>
        SocialFeatureBotType.platformPublish,
      'global' || 'globe' || 'dharma' || 'home' || null =>
        SocialFeatureBotType.globalDharma,
      _ => SocialFeatureBotType.globalDharma,
    };
  }

  void _handleBotSelected(SocialFeatureBotType bot, bool isNarrow) {
    setState(() {
      _selectedBot = bot;
    });
    if (isNarrow) {
      // In narrow (Mobile) mode, push the chat view onto the navigator stack.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF0E1621), // Telegram dark theme chat bg
            body: SocialFeatureChatScreen(botType: bot),
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
            body: isNarrow
                ? _buildNarrowShell()
                : _buildWideShell(),
          );
        },
      ),
    );
  }

  Widget _buildNarrowShell() {
    return TelegramChatList(
      selectedBot: _selectedBot,
      onBotSelected: (bot) => _handleBotSelected(bot, true),
      isMobile: true,
    );
  }

  Widget _buildWideShell() {
    return Row(
      children: [
        TelegramChatList(
          selectedBot: _selectedBot,
          onBotSelected: (bot) => _handleBotSelected(bot, false),
          isMobile: false,
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0E1621), // Chat background
            child: SocialFeatureChatScreen(botType: _selectedBot),
          ),
        ),
      ],
    );
  }
}
