import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../services/membership_service.dart';
import 'login_screen.dart';
import 'membership_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _redeemCodeController = TextEditingController();
  final MembershipService _membershipService = MembershipService();

  @override
  void dispose() {
    _redeemCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 刷新用户信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      if (authModel.isLoggedIn) {
        authModel.refreshUserInfo();
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('您确定要登出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('登出'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      await authModel.logout();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已成功登出'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _handleRedeemCode() async {
    if (_redeemCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入兑换码'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authModel = Provider.of<AuthModel>(context, listen: false);
    
    if (!authModel.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先登录'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await _membershipService.redeemCode(
        authModel.authToken!,
        _redeemCodeController.text.trim(),
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '兑换成功'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 刷新用户信息
        await authModel.refreshUserInfo();
        _redeemCodeController.clear();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '兑换失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('兑换时发生错误: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<AuthModel>(
            builder: (context, authModel, child) {
              if (!authModel.isLoggedIn) {
                return _buildLoginPrompt();
              }
              
              return _buildProfileView(authModel);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 64,
                  color: Color(0xFF667eea),
                ),
                const SizedBox(height: 24),
                const Text(
                  '请先登录',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2c3e50),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '登录后可以享受更多功能，包括会员服务、数据同步等',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7f8c8d),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '立即登录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView(AuthModel authModel) {
    final user = authModel.currentUser!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 用户信息卡片
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // 头像
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF667eea),
                    child: Text(
                      user.username.isNotEmpty 
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 用户名
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2c3e50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 邮箱
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF7f8c8d),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 会员状态
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getMembershipColor(user),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      authModel.getMembershipStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // 会员到期时间
                  if (authModel.getMembershipExpiryText() != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      authModel.getMembershipExpiryText()!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7f8c8d),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 兑换码卡片
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '🎁 兑换码',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2c3e50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _redeemCodeController,
                          decoration: InputDecoration(
                            hintText: '输入兑换码',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _handleRedeemCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('兑换'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 功能菜单
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh, color: Color(0xFF667eea)),
                  title: const Text('刷新用户信息'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    authModel.refreshUserInfo();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('正在刷新用户信息...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.card_membership, color: Color(0xFF667eea)),
                  title: const Text('会员中心'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MembershipScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings, color: Color(0xFF667eea)),
                  title: const Text('账户设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('账户设置功能开发中，敬请期待'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('登出'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Color _getMembershipColor(User user) {
    if (user.isAdmin) return Colors.purple;
    if (user.isPremiumMember) return Colors.amber;
    if (user.isTrialMember) return Colors.blue;
    return Colors.grey;
  }
}