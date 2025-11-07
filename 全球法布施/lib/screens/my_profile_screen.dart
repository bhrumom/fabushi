import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import 'login_screen.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 40, child: Text(user.username[0].toUpperCase())),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(user.email, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard(User user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('会员信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoRow('会员类型', user.membershipType ?? '普通用户'),
            if (user.membershipExpiry != null)
              _buildInfoRow(
                '到期时间',
                '${user.membershipExpiry!.year}-${user.membershipExpiry!.month}-${user.membershipExpiry!.day}',
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
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGuestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person_outline, size: 40, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '游客模式',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text('您正在以游客身份使用应用', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestFeatures(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('游客可用功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildFeatureItem(Icons.public, '全球法布施', '可以向全世界发送佛教经文'),
            _buildFeatureItem(Icons.video_library, '法流观看', '可以观看佛教视频内容'),
            _buildFeatureItem(Icons.temple_buddhist, '禅室体验', '可以进入禅室冥想'),
            const Divider(),
            const Text(
              '登录后可获得更多功能：',
              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
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
            color: isDisabled ? Colors.grey.shade400 : Colors.blue,
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
                    color: isDisabled ? Colors.grey.shade600 : null,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDisabled ? Colors.grey.shade500 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '🙏 登录获得完整体验',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '登录后可以保存您的发送记录，参与排行榜，享受会员服务',
              style: TextStyle(color: Colors.grey),
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
          leading: const Icon(Icons.card_membership),
          title: const Text('购买记录'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: 导航到购买记录页面
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: 导航到设置页面
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('退出登录'),
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
