import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../services/api_client.dart';
import '../../services/local_ai_conversation_store.dart';
import '../../services/project_service.dart';

class CodexSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const CodexSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<CodexSidebar> createState() => _CodexSidebarState();
}

class _CodexSidebarState extends State<CodexSidebar> {
  bool _isCollapsed = false;
  List<LocalProject> _projects = [];
  List<LocalAiConversationRecord> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final projects = await ProjectService.instance.listProjects();
    final chats = await LocalAiConversationStore.instance.list();
    if (mounted) {
      setState(() {
        _projects = projects;
        _chats = chats;
      });
    }
  }

  Future<void> _createNewProject() async {
    final TextEditingController controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新项目', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C2C2E),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '输入项目名称...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await ProjectService.instance.createProject(name.trim());
      _loadData();
    }
  }

  Future<void> _showSettingsPopover() async {
    final authModel = context.read<AuthModel>();

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.18),
      builder: (dialogContext) {
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: _isCollapsed ? 84 : 18,
              bottom: 42,
            ),
            child: _DesktopSettingsPopover(
              authModel: authModel,
              onOpenProfile: () {
                Navigator.of(dialogContext).pop();
                widget.onDestinationSelected(3);
              },
              onOpenSettings: () {
                Navigator.of(dialogContext).pop();
                widget.onDestinationSelected(4);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isCollapsed ? 70 : 260,
      color: const Color(0xFF18181A), // Dark background matching Codex
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40), // Top padding for window controls (macOS)
          
          // Top Actions
          _buildSidebarItem(
            icon: Icons.chat_bubble_outline,
            label: '新对话',
            isSelected: widget.selectedIndex == 0,
            onTap: () => widget.onDestinationSelected(0),
          ),
          _buildSidebarItem(
            icon: Icons.search,
            label: '搜索',
            isSelected: false,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.public,
            label: '全球法布施',
            isSelected: widget.selectedIndex == 1,
            onTap: () => widget.onDestinationSelected(1),
          ),
          _buildSidebarItem(
            icon: Icons.self_improvement,
            label: '禅室',
            isSelected: widget.selectedIndex == 2,
            onTap: () => widget.onDestinationSelected(2),
          ),
          _buildSidebarItem(
            icon: Icons.extension_outlined,
            label: '插件',
            isSelected: false,
            onTap: () {},
          ),
          _buildSidebarItem(
            icon: Icons.auto_awesome_outlined,
            label: '自动化',
            isSelected: false,
            onTap: () {},
          ),
          
          const SizedBox(height: 12),
          
          // Collapse Toggle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 10 : 16.0),
            child: InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_isCollapsed)
                      Text(
                        '全部收起',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    Icon(
                      _isCollapsed ? Icons.keyboard_tab : Icons.menu_open,
                      size: 16,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),

          // Projects Section
          if (!_isCollapsed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '项目',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: _createNewProject,
                    child: Icon(Icons.add, size: 16, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final proj = _projects[index];
                  return _buildProjectItem(proj.name);
                },
              ),
            ),

            // Chats Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '对话',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return _buildChatItem(chat);
                },
              ),
            ),
          ] else ...[
             const Spacer(),
          ],
          
          // Bottom Actions
          _buildSidebarItem(
            icon: Icons.settings_outlined,
            label: '设置',
            isSelected: widget.selectedIndex == 4,
            onTap: _showSettingsPopover,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProjectItem(String name) {
    return InkWell(
      onTap: () {
        // Handle project selection
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 16, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(LocalAiConversationRecord chat) {
    return InkWell(
      onTap: () {
        // Open this chat
        // We will pass this ID to the main screen later
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          chat.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected && !_isCollapsed ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            ),
            if (!_isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _DesktopSettingsPopover extends StatelessWidget {
  const _DesktopSettingsPopover({
    required this.authModel,
    required this.onOpenProfile,
    required this.onOpenSettings,
  });

  final AuthModel authModel;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final user = authModel.currentUser;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xF21E1E22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.36),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '设置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _DesktopProfileSummary(user: user),
            const SizedBox(height: 12),
            _DesktopUsageQuotaCard(
              authToken: authModel.authToken,
              isLoggedIn: user != null,
            ),
            const SizedBox(height: 10),
            _DesktopPopoverItem(
              icon: Icons.person_outline,
              label: '个人资料',
              subtitle: user == null ? '登录后查看个人资料' : '查看账户与修行资料',
              onTap: onOpenProfile,
            ),
            _DesktopPopoverItem(
              icon: Icons.settings_outlined,
              label: '设置',
              subtitle: '应用偏好与智能体设置',
              onTap: onOpenSettings,
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.09),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: user == null
                  ? () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      unawaited(navigator.pushNamed('/login'));
                    }
                  : () {
                      Navigator.of(context).pop();
                      unawaited(authModel.logout());
                    },
              child: Text(user == null ? '登录' : '退出登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopProfileSummary extends StatelessWidget {
  const _DesktopProfileSummary({required this.user});

  final User? user;

  String get _displayName {
    final name = user?.displayName.trim();
    return name == null || name.isEmpty ? '未登录' : name;
  }

  String get _userType {
    if (user == null) return '游客';
    if (user!.isAdmin) return '管理员';
    if (user!.isPremiumMember) return '会员用户';
    if (user!.isTrialMember) return '试用用户';
    final membershipType = user!.membershipType?.trim();
    if (membershipType == null || membershipType.isEmpty) return '普通用户';
    return switch (membershipType) {
      'paid' || 'trial' || 'expired' => '普通用户',
      _ => membershipType,
    };
  }

  String get _accountLine {
    if (user == null) return '登录后同步修行记录和用量';
    if (user!.email.trim().isNotEmpty) return user!.email.trim();
    if (user!.userNo != null) return '@user_${user!.userNo}';
    return user!.username;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _DesktopProfileAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF5CF77),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _accountLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopProfileAvatar extends StatelessWidget {
  const _DesktopProfileAvatar({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatar?.trim();
    final name = user?.displayName.trim() ?? '';
    final initial = name.isEmpty ? '大' : name.substring(0, 1);

    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F455A), Color(0xFF7A5E2D)],
        ),
      ),
      child: avatar != null &&
              (avatar.startsWith('http://') || avatar.startsWith('https://'))
          ? Image.network(
              avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _DesktopAvatarFallback(initial),
            )
          : _DesktopAvatarFallback(initial),
    );
  }
}

class _DesktopAvatarFallback extends StatelessWidget {
  const _DesktopAvatarFallback(this.initial);

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DesktopUsageQuotaCard extends StatefulWidget {
  const _DesktopUsageQuotaCard({
    required this.authToken,
    required this.isLoggedIn,
  });

  final String? authToken;
  final bool isLoggedIn;

  @override
  State<_DesktopUsageQuotaCard> createState() => _DesktopUsageQuotaCardState();
}

class _DesktopUsageQuotaCardState extends State<_DesktopUsageQuotaCard> {
  bool _isLoading = false;
  int _remainingTokens = 0;
  int _usedTokens = 0;
  int _monthlyLimit = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadQuota());
  }

  @override
  void didUpdateWidget(covariant _DesktopUsageQuotaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authToken != widget.authToken ||
        oldWidget.isLoggedIn != widget.isLoggedIn) {
      unawaited(_loadQuota());
    }
  }

  Future<void> _loadQuota() async {
    final token = widget.authToken;
    if (!widget.isLoggedIn || token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _remainingTokens = 0;
        _usedTokens = 0;
        _monthlyLimit = 0;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiClient().getAiQuota(token);
      if (!mounted || widget.authToken != token) return;

      final monthlyLimit = _readInt(result, const [
        'monthlyLimit',
        'monthly_limit',
        'limit',
      ]);
      final usedTokens = _readInt(result, const ['usedTokens', 'used_tokens']);
      final hasRemainingTokens =
          result.containsKey('remainingTokens') ||
          result.containsKey('remaining_tokens');
      final remainingTokens = hasRemainingTokens
          ? _readInt(result, const ['remainingTokens', 'remaining_tokens'])
          : (monthlyLimit - usedTokens).clamp(0, monthlyLimit).toInt();

      setState(() {
        _monthlyLimit = monthlyLimit;
        _usedTokens = usedTokens;
        _remainingTokens = remainingTokens;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('桌面设置用量加载失败: $error');
      if (!mounted || widget.authToken != token) return;
      setState(() {
        _isLoading = false;
        _error = '暂不可用';
      });
    }
  }

  int _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  String _formatTokens(int count) {
    if (count >= 100000000) {
      final yi = count / 100000000;
      return '${yi == yi.truncateToDouble() ? yi.toInt() : yi.toStringAsFixed(1)}亿';
    }
    if (count >= 10000) {
      final wan = count / 10000;
      return '${wan == wan.truncateToDouble() ? wan.toInt() : wan.toStringAsFixed(1)}万';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _monthlyLimit <= 0
        ? 0.0
        : (_usedTokens / _monthlyLimit).clamp(0.0, 1.0).toDouble();
    late final String value;
    late final String subtitle;

    if (!widget.isLoggedIn) {
      value = '登录后查看';
      subtitle = '本月 AI 用量';
    } else if (_isLoading) {
      value = '读取中';
      subtitle = '正在同步本月用量';
    } else if (_monthlyLimit <= 0) {
      value = _error ?? '暂不可用';
      subtitle = '本月额度暂不可用';
    } else {
      value = _error ?? '${_formatTokens(_remainingTokens)} tokens';
      subtitle =
          '已用 ${_formatTokens(_usedTokens)} / 共 ${_formatTokens(_monthlyLimit)}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.data_usage_rounded,
                color: Color(0xFFF5CF77),
                size: 17,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '剩余用量',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.52), fontSize: 12),
          ),
          if (widget.isLoggedIn && _monthlyLimit > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF5CF77)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopPopoverItem extends StatelessWidget {
  const _DesktopPopoverItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.72), size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white30, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
