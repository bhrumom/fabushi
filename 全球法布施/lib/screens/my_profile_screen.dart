import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../models/practice_model.dart';
import 'login_screen.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Consumer2<AuthModel, PracticeModel>(
        builder: (context, authModel, practiceModel, _) {
          final user = authModel.currentUser;
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('请先登录', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ),
                    child: const Text('立即登录'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildUserCard(user),
              const SizedBox(height: 16),
              _buildMembershipCard(user),
              const SizedBox(height: 16),
              _buildStatsCard(practiceModel),
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
            CircleAvatar(
              radius: 40,
              child: Text(user.username[0].toUpperCase()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
              _buildInfoRow('到期时间', '${user.membershipExpiry!.year}-${user.membershipExpiry!.month}-${user.membershipExpiry!.day}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(PracticeModel practiceModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('修习统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoRow('修习时长', '${practiceModel.totalDuration.inMinutes} 分钟'),
            _buildInfoRow('修习次数', '${practiceModel.totalCount}'),
            _buildInfoRow('全球布施流量', '0 MB'), // TODO: 从实际数据获取
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
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
      ],
    );
  }
}
