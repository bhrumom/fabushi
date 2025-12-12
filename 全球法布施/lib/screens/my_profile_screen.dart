import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../models/auth_model.dart';
import '../services/like_service.dart';
import '../services/practice_stats_service.dart';
import 'liked_content_screen.dart';
import 'membership_screen.dart';
import 'edit_profile_screen.dart';
import 'douyin_login_screen.dart';
import 'settings_screen.dart';
import '../core/design_system/app_theme.dart';
import '../widgets/practice_stats_card.dart';
import '../widgets/practice_dialogs.dart';

/// 抖音风格个人中心页面
class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Consumer<AuthModel>(
        builder: (context, authModel, _) {
          final user = authModel.currentUser;
          
          // 设置统计服务的Token
          if (user != null && authModel.authToken != null) {
            PracticeStatsService().setAuthToken(authModel.authToken);
          }
          
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, user, authModel),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      if (user != null) ...[
                        const SizedBox(height: 16),
                        _buildStatsRow(context, user),
                        const SizedBox(height: 20),
                        // 修行统计卡片
                        _buildPracticeStatsCard(context),
                        const SizedBox(height: 20),
                        _buildFeatureGrid(context),
                        const SizedBox(height: 20),
                        _buildMembershipCard(context, user),
                        const SizedBox(height: 20),
                        _buildMenuSection(context, authModel),
                      ] else ...[
                        const SizedBox(height: 20),
                        _buildGuestCard(context),
                        const SizedBox(height: 20),
                        _buildLoginButton(context),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 修行统计卡片
  Widget _buildPracticeStatsCard(BuildContext context) {
    return PracticeStatsCard(
      onTapRecord: () {
        showDialog(
          context: context,
          builder: (context) => const AddPracticeRecordDialog(),
        );
      },
      onTapHistory: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('修行记录功能完善中')),
        );
      },
      onTapDedication: () {
        showDialog(
          context: context,
          builder: (context) => const SetGoalDialog(),
        );
      },
      onTapSettings: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('功课设置功能完善中')),
        );
      },
    );
  }


  Widget _buildSliverAppBar(BuildContext context, User? user, AuthModel authModel) {
    return SliverAppBar(
      expandedHeight: user != null ? 260 : 200,
      pinned: true,
      backgroundColor: const Color(0xFF121212),
      actions: [
        if (user != null)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 渐变背景
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2D2D2D), Color(0xFF121212)],
                ),
              ),
            ),
            // 用户信息
            if (user != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 头像
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 2),
                                    image: user.avatar != null
                                        ? DecorationImage(
                                            image: NetworkImage(user.avatar!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    gradient: user.avatar == null
                                        ? const LinearGradient(
                                            colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                                          )
                                        : null,
                                  ),
                                  child: user.avatar == null
                                      ? Center(
                                          child: Text(
                                            (user.displayName.isNotEmpty ? user.displayName[0] : '?').toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 用户名和ID
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      '抖音号: ${user.username}',
                                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    if (user.isAdmin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Colors.purple, Colors.deepPurple],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          '管理员',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // 编辑资料按钮
                                OutlinedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white30),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    minimumSize: const Size(0, 30),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: const Text('编辑资料', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.person_outline, size: 50, color: Colors.white54),
                      ),
                      const SizedBox(height: 16),
                      const Text('游客模式', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('登录后享受更多功能', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 抖音风格统计栏 - 获赞/关注/粉丝
  Widget _buildStatsRow(BuildContext context, User user) {
    final likeService = LikeService();
    if (!likeService.isInitialized) likeService.initialize();

    return ListenableBuilder(
      listenable: likeService,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('${likeService.likedCount}', '获赞', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LikedContentScreen()));
              }),
              Container(width: 1, height: 30, color: Colors.white12),
              _buildStatItem('0', '关注', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('关注功能开发中')));
              }),
              Container(width: 1, height: 30, color: Colors.white12),
              _buildStatItem('0', '粉丝', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('粉丝功能开发中')));
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      ),
    );
  }

  /// 功能网格 - 抖音风格
  Widget _buildFeatureGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _buildFeatureItem(
          icon: Icons.card_membership,
          label: '会员',
          gradient: const [Color(0xFFD4AF37), Color(0xFFC5A028)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
        ),
        _buildFeatureItem(
          icon: Icons.favorite,
          label: '收藏',
          gradient: const [Color(0xFFFF6B6B), Color(0xFFEE5A5A)],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LikedContentScreen())),
        ),
        _buildFeatureItem(
          icon: Icons.history,
          label: '历史',
          gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('浏览历史开发中'))),
        ),
        _buildFeatureItem(
          icon: Icons.download,
          label: '下载',
          gradient: const [Color(0xFF11998e), Color(0xFF38ef7d)],
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下载管理开发中'))),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 会员卡片
  Widget _buildMembershipCard(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.diamond, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.membershipType ?? '普通用户',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  user.membershipExpiry != null
                      ? '有效期至 ${user.membershipExpiry!.year}.${user.membershipExpiry!.month}.${user.membershipExpiry!.day}'
                      : '升级会员解锁更多功能',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('升级', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 菜单列表
  Widget _buildMenuSection(BuildContext context, AuthModel authModel) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.refresh,
            title: '刷新数据',
            onTap: () async {
              await authModel.refreshUserInfo();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据已刷新'), backgroundColor: Colors.green));
              }
            },
          ),
          const Divider(color: Colors.white10, height: 1, indent: 56),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('帮助功能开发中'))),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 56),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '关于',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: '全球法布施',
              applicationVersion: '1.0.0',
              children: [const Text('传播佛法，利益众生')],
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 56),
          _buildMenuItem(
            icon: Icons.logout,
            title: '退出登录',
            isDestructive: true,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('确认退出', style: TextStyle(color: Colors.white)),
                  content: const Text('确定要退出登录吗？', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('退出', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await authModel.logout();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已退出登录')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap, bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white54, size: 22),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  /// 游客卡片
  Widget _buildGuestCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFD4AF37), size: 20),
              SizedBox(width: 8),
              Text('游客可用功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuestFeatureItem(Icons.public, '全球法布施'),
          _buildGuestFeatureItem(Icons.video_library, '法流观看'),
          _buildGuestFeatureItem(Icons.self_improvement, '禅室体验'),
          const SizedBox(height: 12),
          const Text(
            '登录后可同步数据、使用会员功能等',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestFeatureItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  /// 登录按钮
  Widget _buildLoginButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF6B6B).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DouyinLoginScreen())),
          child: const Center(
            child: Text(
              '立即登录 / 注册',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
