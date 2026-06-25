import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/application/auth_model.dart';
import '../../services/social_friend_service.dart';
import 'social_feature_bot.dart';

class SocialContactsSidebar extends StatefulWidget {
  const SocialContactsSidebar({
    super.key,
    required this.selectedBot,
    required this.onBotSelected,
    this.onClose,
    this.isMobile = false,
  });

  final SocialFeatureBotType selectedBot;
  final ValueChanged<SocialFeatureBotType> onBotSelected;
  final VoidCallback? onClose;
  final bool isMobile;

  @override
  State<SocialContactsSidebar> createState() => _SocialContactsSidebarState();
}

class _SocialContactsSidebarState extends State<SocialContactsSidebar> {
  static const List<SocialFeatureBotType> _fixedBots = [
    SocialFeatureBotType.globalDharma,
    SocialFeatureBotType.flashcards,
    SocialFeatureBotType.platformPublish,
  ];

  final SocialFriendService _friendService = SocialFriendService();
  final TextEditingController _filterController = TextEditingController();
  List<SocialFriendContact> _friends = const [];
  bool _isLoadingFriends = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() {
      setState(() => _filter = _filterController.text.trim());
    });
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

  @override
  Widget build(BuildContext context) {
    final width = widget.isMobile
        ? (MediaQuery.sizeOf(context).width * 0.86).clamp(312.0, 380.0)
        : 364.0;
    final authModel = Provider.of<AuthModel?>(context);
    final friends = _filteredFriends;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        border: Border(right: BorderSide(color: Color(0xFF223040))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildAccountHeader(authModel),
            _buildSearchRow(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFriends,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SectionLabel(
                      label: '固定机器人',
                      trailing: 'PINNED',
                    ),
                    for (final type in _fixedBots)
                      _FeatureBotTile(
                        bot: type.bot,
                        selected: widget.selectedBot == type,
                        onTap: () => widget.onBotSelected(type),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (friends.isEmpty)
                      _EmptyFriendHint(
                        onAddFriend: _showAddFriendDialog,
                      )
                    else
                      for (final friend in friends)
                        _FriendTile(
                          friend: friend,
                          onTap: () => _showFriendPendingNotice(friend),
                        ),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
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

  Widget _buildAccountHeader(AuthModel? authModel) {
    final name = _displayName(authModel);
    final initial = name.isEmpty ? 'BO' : name.substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFF9F43),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'bhrum om' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '社交联系人 · 功能机器人',
                  style: TextStyle(
                    color: Color(0xFF91A3B7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              tooltip: '关闭',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, color: Color(0xFF91A3B7)),
            ),
        ],
      ),
    );
  }

  String _displayName(AuthModel? authModel) {
    final user = authModel?.currentUser;
    final display = user?.displayName.trim() ?? '';
    if (display.isNotEmpty) return display;
    return user?.username ?? '';
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _filterController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索联系人',
                hintStyle: const TextStyle(color: Color(0xFF728196)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF728196)),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF101923),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '添加好友',
            onPressed: _showAddFriendDialog,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF243446),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.person_add_alt_1),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '好友申请',
            onPressed: _showFriendRequestsSheet,
            icon: const Icon(Icons.notifications_none, color: Color(0xFF91A3B7)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF223040))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BottomAction(
              icon: Icons.person_outline,
              label: '资料',
              onTap: () => _showSnack('个人资料入口保持原有功能，后续可接入完整资料页。'),
            ),
          ),
          Expanded(
            child: _BottomAction(
              icon: Icons.refresh,
              label: '同步',
              onTap: _loadFriends,
            ),
          ),
          Expanded(
            child: _BottomAction(
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: () => _showSnack('设置入口保持原有功能，后续可接入完整设置页。'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFriendDialog() async {
    final controller = TextEditingController(text: _filter);
    List<SocialFriendContact> results = const [];
    var searching = false;
    String? message;

    Future<void> runSearch(StateSetter setDialogState) async {
      final keyword = controller.text.trim();
      if (keyword.isEmpty) {
        setDialogState(() => message = '请输入昵称、用户名或手机号');
        return;
      }
      setDialogState(() {
        searching = true;
        message = null;
      });
      final found = await _friendService.searchUsers(keyword, token: _authToken);
      if (!mounted) return;
      setDialogState(() {
        results = found;
        searching = false;
        message = found.isEmpty ? '没有找到匹配的用户' : null;
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF17212B),
              surfaceTintColor: Colors.transparent,
              title: const Text(
                '添加好友',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '搜索好友账号',
                        hintStyle: const TextStyle(color: Color(0xFF728196)),
                        filled: true,
                        fillColor: const Color(0xFF101923),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF728196)),
                        suffixIcon: IconButton(
                          onPressed: searching ? null : () => runSearch(setDialogState),
                          icon: const Icon(Icons.arrow_forward, color: Color(0xFF91A3B7)),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF263445)),
                        ),
                      ),
                      onSubmitted: (_) => runSearch(setDialogState),
                    ),
                    const SizedBox(height: 14),
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          message!,
                          style: const TextStyle(color: Color(0xFF91A3B7)),
                        ),
                      )
                    else if (results.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(color: Color(0xFF263445)),
                          itemBuilder: (context, index) {
                            final user = results[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _ContactAvatar(contact: user),
                              title: Text(
                                user.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                user.username.isEmpty ? user.id : '@${user.username}',
                                style: const TextStyle(color: Color(0xFF91A3B7)),
                              ),
                              trailing: FilledButton(
                                onPressed: () async {
                                  await _friendService.sendFriendRequest(
                                    user,
                                    token: _authToken,
                                    message: '请求添加好友',
                                  );
                                  if (!mounted) return;
                                  _showSnack('已发送好友申请');
                                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                                },
                                child: const Text('添加'),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _showFriendRequestsSheet() async {
    final requests = await _friendService.listIncomingRequests(token: _authToken);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              color: Color(0xFF17212B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF728196),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '好友申请',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        '暂无新的好友申请',
                        style: TextStyle(color: Color(0xFF91A3B7)),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const Divider(color: Color(0xFF263445)),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return ListTile(
                          leading: _ContactAvatar(contact: request.fromUser),
                          title: Text(
                            request.fromUser.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            request.message.isEmpty ? '请求添加你为好友' : request.message,
                            style: const TextStyle(color: Color(0xFF91A3B7)),
                          ),
                          trailing: FilledButton(
                            onPressed: () async {
                              try {
                                await _friendService.acceptFriendRequest(
                                  request.id,
                                  token: _authToken,
                                );
                                if (!mounted) return;
                                _showSnack('已同意好友申请');
                                unawaited(_loadFriends());
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                              } catch (error) {
                                if (!mounted) return;
                                _showSnack('同意失败：$error', isError: true);
                              }
                            },
                            child: const Text('同意'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFriendPendingNotice(SocialFriendContact friend) {
    _showSnack('${friend.displayName} 的私聊会在下一步接入消息服务');
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2B5278),
      ),
    );
  }
}

class _FeatureBotTile extends StatelessWidget {
  const _FeatureBotTile({
    required this.bot,
    required this.selected,
    required this.onTap,
  });

  final SocialFeatureBot bot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2B5278) : Colors.transparent,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: bot.avatarColor,
              child: Icon(bot.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bot.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bot.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? const Color(0xFFD9ECFF) : const Color(0xFF91A3B7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.done_all, color: Color(0xFFD9ECFF), size: 18),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});

  final SocialFriendContact friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 9, 14, 9),
        child: Row(
          children: [
            _ContactAvatar(contact: friend),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    friend.status == 'pending'
                        ? '等待通过'
                        : (friend.username.isEmpty ? '已添加好友' : '@${friend.username}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF91A3B7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.contact});

  final SocialFriendContact contact;

  @override
  Widget build(BuildContext context) {
    final initial = contact.displayName.isEmpty
        ? '友'
        : contact.displayName.substring(0, 1).toUpperCase();
    final avatar = contact.avatarUrl.trim();
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF3D8BFF),
      backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
      child: avatar.startsWith('http')
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF728196),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF728196),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFriendHint extends StatelessWidget {
  const _EmptyFriendHint({required this.onAddFriend});

  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.people_outline, color: Color(0xFF728196), size: 34),
          const SizedBox(height: 10),
          const Text(
            '还没有好友，搜索账号并发送申请，对方同意后会出现在这里。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF91A3B7), height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAddFriend,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('添加好友'),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF91A3B7), size: 21),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF91A3B7),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
