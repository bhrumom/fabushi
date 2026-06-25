import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../widgets/social/social_contacts_sidebar.dart';
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
  bool _mobileSidebarOpen = false;

  bool get _isMobileRuntime => Platform.isAndroid || Platform.isIOS;

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

  void _selectBot(SocialFeatureBotType botType) {
    setState(() {
      _selectedBot = botType;
      _mobileSidebarOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _isMobileRuntime ? _buildMobileShell() : _buildDesktopShell(),
      ),
    );
  }

  Widget _buildDesktopShell() {
    return Row(
      children: [
        SocialContactsSidebar(
          selectedBot: _selectedBot,
          onBotSelected: _selectBot,
        ),
        Expanded(
          child: SocialFeatureChatScreen(botType: _selectedBot),
        ),
      ],
    );
  }

  Widget _buildMobileShell() {
    return Stack(
      children: [
        Positioned.fill(
          child: SocialFeatureChatScreen(botType: _selectedBot),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: SafeArea(
            child: _SidebarOpenButton(
              onPressed: () => setState(() => _mobileSidebarOpen = true),
            ),
          ),
        ),
        if (_mobileSidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _mobileSidebarOpen = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: _mobileSidebarOpen ? 0 : -MediaQuery.sizeOf(context).width,
          top: 0,
          bottom: 0,
          child: SocialContactsSidebar(
            selectedBot: _selectedBot,
            onBotSelected: _selectBot,
            onClose: () => setState(() => _mobileSidebarOpen = false),
            isMobile: true,
          ),
        ),
      ],
    );
  }
}

class _SidebarOpenButton extends StatelessWidget {
  const _SidebarOpenButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC17212B),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: '打开联系人',
        onPressed: onPressed,
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
