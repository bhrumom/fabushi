import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/application/auth_model.dart';
import '../../services/mini_app_registry_service.dart';
import '../../services/social_friend_service.dart';
import '../social/social_feature_bot.dart';

class TelegramChatList extends StatefulWidget {
  const TelegramChatList({
    super.key,
    required this.selectedBot,
    required this.onBotSelected,
    this.isMobile = false,
  });

  final String selectedBot;
  final ValueChanged<SocialFeatureBot> onBotSelected;
  final bool isMobile;

  @override
  State<TelegramChatList> createState() => _TelegramChatListState();
}

class _TelegramChatListState extends State<TelegramChatList> {
  final SocialFriendService _friendService = SocialFriendService();
  final TextEditingController _filterController = TextEditingController();
  List<SocialFriendContact> _friends = const [];
  List<SocialFeatureBot> _bots = defaultSocialMiniAppBots();
  bool _isLoadingFriends = false;
  bool _isLoadingBots = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() {
      setState(() => _filter = _filterController.text.trim());
    });
    unawaited(_loadBots());
    unawaited(_loadFriends());
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  String? get _authToken {
    try {
      return Provider.of<AuthModel?>(context, listen: false)?.authToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    final friends = await _friendService.listFriends(token: _authToken);
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _isLoadingFriends = false;
    });
  }

  Future<void> _loadBots() async {
    setState(() => _isLoadingBots = true);
    final service = MiniAppRegistryService(
      tokenProvider: () async => _authToken,
    );
    final registry = await service.loadRegistry(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _bots = [
        for (var i = 0; i < registry.bots.length; i++)
          SocialFeatureBot.fromMiniApp(
            registry.bots[i],
            index: i,
            manifest: registry.manifestFor(registry.bots[i].miniAppId),
          ),
      ];
      _isLoadingBots = false;
    });
  }

  List<SocialFriendContact> get _filteredFriends {
    final query = _filter.toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends
        .where(
          (friend) =>
              friend.displayName.toLowerCase().contains(query) ||
              friend.username.toLowerCase().contains(query),
        )
        .toList();
  }

  List<SocialFeatureBot> get _filteredBots {
    final query = _filter.toLowerCase();
    if (query.isEmpty) return _bots;
    return _bots.where((bot) {
      return bot.title.toLowerCase().contains(query) ||
          bot.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.isMobile ? double.infinity : 320.0;
    final friends = _filteredFriends;
    final bots = _filteredBots;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        border: Border(right: BorderSide(color: Color(0xFF223040), width: 1)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _buildSearchRow(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFriends,
                color: const Color(0xFF40A7E3),
                backgroundColor: const Color(0xFF232E3C),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SectionLabel(
                      label: '小程序机器人',
                      trailing: _isLoadingBots ? '同步中' : 'PINNED',
                    ),
                    for (final bot in bots)
                      _ChatTile(
                        title: bot.title,
                        subtitle: bot.subtitle,
                        avatarColor: bot.avatarColor,
                        icon: bot.icon,
                        selected: widget.selectedBot == bot.stableBotId,
                        onTap: () => widget.onBotSelected(bot),
                      ),
                    const SizedBox(height: 8),
                    _SectionLabel(
                      label: '好友',
                      trailing: _isLoadingFriends ? '同步中' : '${friends.length}',
                    ),
                    if (_isLoadingFriends)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF40A7E3),
                            ),
                          ),
                        ),
                      )
                    else if (friends.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          '暂无好友',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final friend in friends)
                        _ChatTile(
                          title: friend.displayName,
                          subtitle: friend.status == 'pending'
                              ? '等待通过'
                              : (friend.username.isEmpty
                                    ? '已添加好友'
                                    : '@${friend.username}'),
                          avatarUrl: friend.avatarUrl.isNotEmpty
                              ? friend.avatarUrl
                              : null,
                          avatarColor: const Color(0xFF3D8BFF),
                          selected: false,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${friend.displayName} 的私聊会在下一步接入',
                                ),
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF91A3B7)),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _filterController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索联系人',
                hintStyle: const TextStyle(color: Color(0xFF728196)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF728196),
                  size: 20,
                ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF242F3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.title,
    required this.subtitle,
    required this.avatarColor,
    this.icon,
    this.avatarUrl,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color avatarColor;
  final IconData? icon;
  final String? avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = title.isEmpty ? '?' : title.substring(0, 1).toUpperCase();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2B5278) : Colors.transparent,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarColor,
              backgroundImage:
                  (avatarUrl != null && avatarUrl!.startsWith('http'))
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: (avatarUrl == null || !avatarUrl!.startsWith('http'))
                  ? (icon != null
                        ? Icon(icon, color: Colors.white, size: 24)
                        : Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFD9ECFF)
                          : const Color(0xFF91A3B7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.trailing});

  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF728196),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF728196),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
