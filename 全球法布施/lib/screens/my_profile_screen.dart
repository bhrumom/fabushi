import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../services/like_service.dart';
import 'liked_content_screen.dart';
import 'login_screen.dart';
import 'membership_screen.dart';
import '../core/design_system/app_theme.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<AuthModel>(
        builder: (context, authModel, _) {
          final user = authModel.currentUser;
          if (user == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGuestCard(),
                const SizedBox(height: 16),
                _buildGuestFeatures(context),
                const SizedBox(height: 16),
                _buildLoginPrompt(context),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildUserCard(user),
              const SizedBox(height: 16),
              _buildLikedSection(context),
              const SizedBox(height: 16),
              _buildMembershipCard(user),
              const SizedBox(height: 16),
              _buildActionButtons(context, authModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Container(
      decoration: AppTheme.glassDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40, 
              backgroundColor: AppTheme.primaryColor,
              child: Text(user.username[0].toUpperCase(), style: const TextStyle(color: Colors.white))
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(user.email, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard(User user) {
    return Container(
      decoration: AppTheme.glassDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('会员信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                if (user.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('管理员', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('会员类型', user.membershipType ?? '普通用户'),
            if (user.membershipExpiry != null)
              _buildInfoRow(
                '到期时间',
                '${user.membershipExpiry!.year}-${user.membershipExpiry!.month.toString().padLeft(2, '0')}-${user.membershipExpiry!.day.toString().padLeft(2, '0')}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildGuestCard() {
    return Container(
      decoration: AppTheme.glassDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white24,
              child: const Icon(Icons.person_outline, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '游客模式',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text('您正在以游客身份使用应用', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestFeatures(BuildContext context) {
    return Container(
      decoration: AppTheme.glassDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('游客可用功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _buildFeatureItem(Icons.public, '全球法布施', '可以向全世界发送佛教经文'),
            _buildFeatureItem(Icons.video_library, '法流观看', '可以观看佛教视频内容'),
            _buildFeatureItem(Icons.temple_buddhist, '禅室体验', '可以进入禅室冥想'),
            const Divider(color: Colors.white24),
            const Text(
              '登录后可获得更多功能：',
              style: TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem(Icons.cloud_sync, '云端同步', '数据云端保存，多设备同步', isDisabled: true),
            _buildFeatureItem(Icons.leaderboard, '排行榜', '查看全球发送排行榜', isDisabled: true),
            _buildFeatureItem(Icons.card_membership, '会员服务', '享受会员专属服务', isDisabled: true),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, {bool isDisabled = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDisabled ? Colors.white24 : AppTheme.accentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDisabled ? Colors.white38 : Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDisabled ? Colors.white24 : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedSection(BuildContext context) {
    final likeService = LikeService();
    
    // 确保服务已初始化
    if (!likeService.isInitialized) {
      likeService.initialize();
    }
    
    return ListenableBuilder(
      listenable: likeService,
      builder: (context, _) {
        final likedCount = likeService.likedCount;
        return Container(
          decoration: AppTheme.glassDecoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LikedContentScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.favorite, color: Colors.redAccent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '我的喜欢',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            likedCount > 0 ? '$likedCount 个内容' : '还没有喜欢的内容',
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Container(
      decoration: AppTheme.glassDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '🙏 登录获得完整体验',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              '登录后可以保存您的发送记录，参与排行榜，享受会员服务',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white70),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('登录'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('注册'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AuthModel authModel) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.card_membership, color: Colors.white),
          title: const Text('会员中心', style: TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MembershipScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh, color: Colors.white),
          title: const Text('刷新会员信息', style: TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
          onTap: () async {
            await authModel.refreshUserInfo();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已刷新会员信息')),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings, color: Colors.white),
          title: const Text('设置', style: TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('设置功能开发中')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.white),
          title: const Text('退出登录', style: TextStyle(color: Colors.white)),
          onTap: () async {
            await authModel.logout();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录，您现在以游客身份使用')),
              );
            }
          },
        ),
      ],
    );
  }
}
