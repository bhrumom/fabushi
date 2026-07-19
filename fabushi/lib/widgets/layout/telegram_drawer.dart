import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/application/auth_model.dart';
import '../auth/unified_login_dialog.dart';
import '../../screens/settings_screen.dart';
import '../../screens/telegram_authorization_screen.dart';

class TelegramDrawer extends StatelessWidget {
  const TelegramDrawer({super.key});

  Future<void> _openLogin(BuildContext context) async {
    final success = await UnifiedLoginDialog.show(context);
    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel?>();
    final user = authModel?.currentUser;
    final isLoggedIn = user != null;

    final avatar = user?.avatar?.trim();
    final name = user?.displayName.trim() ?? '未登录';
    final initial = name.isEmpty ? '大' : name.substring(0, 1).toUpperCase();
    final phone = user?.phoneNumber ?? user?.username ?? '登录后体验完整功能';

    return Drawer(
      backgroundColor: const Color(0xFF1C242F),
      child: Column(
        children: [
          _buildHeader(context, isLoggedIn, name, phone, initial, avatar),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (!isLoggedIn)
                  _DrawerItem(
                    icon: Icons.add_circle_outline,
                    label: '登录 / 注册',
                    onTap: () {
                      Navigator.pop(context);
                      _openLogin(context);
                    },
                  ),
                _DrawerItem(
                  icon: Icons.public,
                  label: '全球法布施主页 (3D Earth)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/',
                    ); // Or whatever the route is
                  },
                ),
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: '联系人',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('侧边栏已整合联系人')));
                  },
                ),
                _DrawerItem(
                  icon: Icons.send_rounded,
                  label: 'Telegram 账号',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TelegramAuthorizationScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.self_improvement,
                  label: '静修室 (Meditation)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/meditation');
                  },
                ),
                _DrawerItem(
                  icon: Icons.menu_book,
                  label: '读经/听经',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/sutra');
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: '设置',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(color: Colors.white12, height: 16),
                _DrawerItem(
                  icon: Icons.help_outline,
                  label: '关于我们',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('大乘 - 全球法布施网络 v1.0')),
                    );
                  },
                ),
                if (isLoggedIn) ...[
                  const Divider(color: Colors.white12, height: 16),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: '退出登录',
                    onTap: () {
                      Navigator.pop(context);
                      if (authModel != null) {
                        authModel.logout();
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('已退出登录')));
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isLoggedIn,
    String name,
    String phone,
    String initial,
    String? avatarUrl,
  ) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      color: const Color(0xFF232E3C), // Slightly lighter than drawer bg
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF40A7E3),
                backgroundImage:
                    (avatarUrl != null && avatarUrl.startsWith('http'))
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || !avatarUrl.startsWith('http'))
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              IconButton(
                icon: const Icon(
                  Icons.brightness_4_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  // Toggle dark mode (placeholder)
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isLoggedIn)
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF91A3B7), size: 24),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 20,
    );
  }
}
