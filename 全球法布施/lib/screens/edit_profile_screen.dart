import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../services/auth_service.dart';
import '../core/design_system/app_theme.dart';
import '../services/meditation_session_manager.dart';

/// 抖音风格编辑资料页面
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _avatarController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthModel>().currentUser;
    _nicknameController = TextEditingController(text: user?.nickname ?? user?.username ?? '');
    _avatarController = TextEditingController(text: user?.avatar ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = AuthService();
    final result = await authService.updateProfile(
      nickname: _nicknameController.text.trim(),
      avatar: _avatarController.text.trim().isEmpty ? null : _avatarController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        // 刷新AuthModel中的用户信息
        await context.read<AuthModel>().refreshUserInfo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('个人资料更新成功'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '更新失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthModel>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text('编辑资料', style: TextStyle(color: Colors.white, fontSize: 17)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                  )
                : const Text('保存', style: TextStyle(color: AppTheme.primaryColor, fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 24),
              // 头像区域
              _buildAvatarSection(user),
              const SizedBox(height: 32),
              // 表单区域
              _buildFormSection(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(User? user) {
    return GestureDetector(
      onTap: () {
        // TODO: 实现头像选择器
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传功能开发中')),
        );
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  gradient: _avatarController.text.isEmpty
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  image: _avatarController.text.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_avatarController.text),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        )
                      : null,
                ),
                child: _avatarController.text.isEmpty
                    ? Center(
                        child: Text(
                          (user?.displayName.isNotEmpty == true ? user!.displayName[0] : '?').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF121212), width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '点击更换头像',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(User? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 昵称
          _buildFormItem(
            label: '昵称',
            child: TextFormField(
              controller: _nicknameController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请输入昵称',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入昵称';
                }
                return null;
              },
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
          // 一门深入（锁定功课）
          _buildInfoItem(
            label: '一门深入',
            value: MeditationSessionManager().lockedPractice?.title ?? '未选择',
            showArrow: false,
          ),
          const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
          // 手机号
          _buildInfoItem(
            label: '手机号',
            value: user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty
                ? _maskPhoneNumber(user.phoneNumber!)
                : '未绑定',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('手机号更换功能开发中')),
              );
            },
          ),
          const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
          // 头像URL (临时，后续改为上传)
          _buildFormItem(
            label: '头像链接',
            child: TextFormField(
              controller: _avatarController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请输入头像图片URL',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormItem({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: value == '未绑定' ? Colors.white38 : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  String _maskPhoneNumber(String phone) {
    if (phone.length < 7) return phone;
    // 隐藏中间4位: 138****1234
    return '${phone.substring(0, phone.length - 8)}****${phone.substring(phone.length - 4)}';
  }
}
