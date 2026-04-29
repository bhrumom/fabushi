import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design_system/app_theme.dart';
import '../models/auth_model.dart';
import '../services/http_service.dart';
import '../services/meditation_session_manager.dart';

/// 编辑资料页面
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _avatarController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasPassword = true;
  String? _pendingAvatarBase64;
  String? _pendingAvatarFileName;
  String? _pendingAvatarContentType;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthModel>().currentUser;
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _avatarController = TextEditingController(text: user?.avatar ?? '');
    _loadPasswordState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _loadPasswordState() async {
    try {
      final response = await HttpService.get(
        AppConfig.adminCheckStatusUrl,
        useAuth: true,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted && data.containsKey('hasPassword')) {
          setState(() => _hasPassword = data['hasPassword'] == true);
        }
      }
    } catch (_) {
      // 旧后端没有返回 hasPassword 时，保守地隐藏设置密码入口。
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    if (bytes.length > 3 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像图片不能超过 3MB')),
      );
      return;
    }

    setState(() {
      _pendingAvatarBase64 = base64Encode(bytes);
      _pendingAvatarFileName = file.name;
      _pendingAvatarContentType = _contentTypeForName(file.name);
    });
  }

  String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final body = <String, dynamic>{
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'avatar': _avatarController.text.trim(),
    };

    if (!_hasPassword && _passwordController.text.isNotEmpty) {
      body['password'] = _passwordController.text;
    }

    if (_pendingAvatarBase64 != null) {
      body['avatarData'] = {
        'imageBase64': _pendingAvatarBase64,
        'fileName': _pendingAvatarFileName,
        'contentType': _pendingAvatarContentType,
      };
    }

    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/auth/update-profile',
        body: body,
        useAuth: true,
      );
      final data = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'] as String?;
        final userJson = data['user'];
        final updatedUsername = userJson is Map
            ? (userJson['username'] as String? ??
                  _usernameController.text.trim())
            : _usernameController.text.trim();

        final authModel = context.read<AuthModel>();
        if (token != null) {
          await authModel.loginWithToken(token, updatedUsername);
        } else {
          await authModel.refreshUserInfo();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('个人资料更新成功'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? '更新失败')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败: $e')),
      );
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
        title: const Text(
          '编辑资料',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
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
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildAvatarSection(user),
              const SizedBox(height: 32),
              _buildFormSection(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(User? user) {
    return GestureDetector(
      onTap: _pickAvatar,
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
                  gradient:
                      (_avatarController.text.isEmpty &&
                          _pendingAvatarBase64 == null)
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                        )
                      : null,
                  image: _buildAvatarImage(),
                ),
                child:
                    (_avatarController.text.isEmpty &&
                        _pendingAvatarBase64 == null)
                    ? Center(
                        child: Text(
                          (user?.username.isNotEmpty == true
                                  ? user!.username[0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF121212),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '点击从本地选择头像',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  DecorationImage? _buildAvatarImage() {
    if (_pendingAvatarBase64 != null) {
      return DecorationImage(
        image: MemoryImage(base64Decode(_pendingAvatarBase64!)),
        fit: BoxFit.cover,
      );
    }
    if (_avatarController.text.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(_avatarController.text),
        fit: BoxFit.cover,
      );
    }
    return null;
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
          _buildFormItem(
            label: '用户名',
            child: TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请输入用户名',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              validator: (value) {
                final username = value?.trim() ?? '';
                if (username.isEmpty) return '请输入用户名';
                if (username.contains('@') ||
                    username.contains(RegExp(r'\s'))) {
                  return '用户名不能包含 @ 或空格';
                }
                if (username.length < 2 || username.length > 32) {
                  return '用户名长度需为 2-32 个字符';
                }
                return null;
              },
            ),
          ),
          _divider(),
          _buildFormItem(
            label: '邮箱',
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请输入邮箱',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  return '邮箱格式不正确';
                }
                return null;
              },
            ),
          ),
          _divider(),
          _buildFormItem(
            label: '手机号',
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '请输入手机号',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isEmpty) return null;
                if (!RegExp(r'^\+?[0-9]{6,20}$').hasMatch(phone)) {
                  return '手机号格式不正确';
                }
                return null;
              },
            ),
          ),
          if (!_hasPassword) ...[
            _divider(),
            _buildFormItem(
              label: '设置密码',
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '设置后可用账号密码登录',
                  hintStyle: const TextStyle(color: Colors.white38),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return null;
                  if (value!.length < 6) return '密码至少 6 位';
                  return null;
                },
              ),
            ),
            _divider(),
            _buildFormItem(
              label: '确认密码',
              child: TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '再次输入密码',
                  hintStyle: const TextStyle(color: Colors.white38),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                validator: (value) {
                  if (_passwordController.text.isEmpty) return null;
                  if (value != _passwordController.text) return '两次输入的密码不一致';
                  return null;
                },
              ),
            ),
          ],
          _divider(),
          _buildInfoItem(
            label: '一门深入',
            value: MeditationSessionManager().lockedPractice?.title ?? '未选择',
            showArrow: false,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16);

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
}
