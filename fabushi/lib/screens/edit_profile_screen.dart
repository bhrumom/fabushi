import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design_system/app_theme.dart';
import '../models/auth_model.dart';
import '../models/leaderboard_model.dart';
import '../services/error_report_service.dart';
import '../services/http_service.dart';
import '../services/meditation_session_manager.dart';

class _PreparedAvatarUpload {
  final String base64;
  final String fileName;
  final String contentType;
  final bool wasCompressed;

  const _PreparedAvatarUpload({
    required this.base64,
    required this.fileName,
    required this.contentType,
    required this.wasCompressed,
  });
}

/// 编辑资料页面
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxAvatarBytes = 3 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
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
    _displayNameController = TextEditingController(text: user?.nickname ?? '');
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
    _displayNameController.dispose();
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
    if (file == null || file.bytes == null) return;

    final prepared = _prepareAvatarUpload(file);
    if (prepared == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像图片处理失败，请换一张图片重试')),
      );
      return;
    }

    setState(() {
      _pendingAvatarBase64 = prepared.base64;
      _pendingAvatarFileName = prepared.fileName;
      _pendingAvatarContentType = prepared.contentType;
    });

    if (prepared.wasCompressed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像图片过大，已自动压缩到可上传大小')),
      );
    }
  }

  _PreparedAvatarUpload? _prepareAvatarUpload(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    if (bytes.length <= _maxAvatarBytes) {
      return _PreparedAvatarUpload(
        base64: base64Encode(bytes),
        fileName: file.name,
        contentType: _contentTypeForName(file.name),
        wasCompressed: false,
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    const qualities = [88, 80, 72, 64, 56, 48, 40, 32];
    final originalMaxSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    var targetMaxSide = originalMaxSide > 1600 ? 1600 : originalMaxSide;
    Uint8List? encodedBytes;

    while (targetMaxSide >= 720) {
      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? targetMaxSide : null,
        height: decoded.height > decoded.width ? targetMaxSide : null,
        interpolation: img.Interpolation.average,
      );

      for (final quality in qualities) {
        final candidate = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
        if (candidate.length <= _maxAvatarBytes) {
          encodedBytes = candidate;
          break;
        }
      }

      if (encodedBytes != null) {
        break;
      }

      if (targetMaxSide == 720) {
        break;
      }
      final nextSide = (targetMaxSide * 0.8).round();
      targetMaxSide = nextSide < 720 ? 720 : nextSide;
    }

    if (encodedBytes == null) {
      return null;
    }

    return _PreparedAvatarUpload(
      base64: base64Encode(encodedBytes),
      fileName: _compressedAvatarFileName(file.name),
      contentType: 'image/jpeg',
      wasCompressed: true,
    );
  }

  String _compressedAvatarFileName(String originalName) {
    final dotIndex = originalName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? originalName.substring(0, dotIndex) : originalName;
    final safeBaseName = baseName.trim().isEmpty ? 'avatar' : baseName.trim();
    return '${safeBaseName}_compressed.jpg';
  }

  String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _maskEmail(String value) {
    if (value.isEmpty || !value.contains('@')) return value;
    final parts = value.split('@');
    final local = parts.first;
    final domain = parts.sublist(1).join('@');
    if (local.length <= 2) return '${local[0]}*@${domain}';
    return '${local.substring(0, 2)}***@${domain}';
  }

  String _maskPhone(String value) {
    if (value.length < 7) return value;
    return '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
  }

  String _trimPreview(String value, {int maxLength = 600}) {
    final normalized = value.trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }

  Map<String, dynamic> _buildProfileFailureDiagnostics({
    int? statusCode,
    String? serverError,
    String? responseBodyPreview,
  }) {
    final currentUser = context.read<AuthModel>().currentUser;
    return {
      'attemptedDisplayName': _displayNameController.text.trim(),
      'attemptedUsername': _usernameController.text.trim(),
      'attemptedEmail': _maskEmail(_emailController.text.trim()),
      'attemptedPhone': _maskPhone(_phoneController.text.trim()),
      'changedDisplayName': currentUser?.nickname != _displayNameController.text.trim(),
      'changedUsername': currentUser?.username != _usernameController.text.trim(),
      'changedEmail': currentUser?.email != _emailController.text.trim(),
      'changedPhone': currentUser?.phoneNumber != _phoneController.text.trim(),
      'hasPendingAvatarUpload': _pendingAvatarBase64 != null,
      'hasPasswordSetupAttempt': !_hasPassword && _passwordController.text.isNotEmpty,
      if (statusCode != null) 'statusCode': statusCode,
      if (serverError != null && serverError.isNotEmpty) 'serverError': serverError,
      if (responseBodyPreview != null && responseBodyPreview.isNotEmpty)
        'responseBodyPreview': _trimPreview(responseBodyPreview),
    };
  }

  Future<String?> _autoReportProfileFailure({
    required String source,
    Object? error,
    StackTrace? stackTrace,
    int? statusCode,
    String? serverError,
    String? responseBodyPreview,
  }) async {
    try {
      await ErrorReportService.instance.recordError(
        error ?? serverError ?? '个人资料更新失败',
        stackTrace: stackTrace,
        stage: 'profile_update',
        source: source,
        fatal: false,
        extra: _buildProfileFailureDiagnostics(
          statusCode: statusCode,
          serverError: serverError,
          responseBodyPreview: responseBodyPreview,
        ),
      );

      final result = await ErrorReportService.instance.submitLastReport(
        title: '编辑资料失败自动报告',
        userDescription: '用户在编辑资料页保存资料时失败，客户端已自动补充请求上下文与服务端返回。',
        contact: '',
        authToken: context.read<AuthModel>().authToken,
        page: 'edit_profile_screen',
        category: 'profile_update_failure',
      );

      if (result['success'] == true && result['issueNumber'] != null) {
        return '#${result['issueNumber']}';
      }
    } catch (_) {
      // 自动上报失败时不再打断用户原始错误提示。
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authModel = context.read<AuthModel>();
    final currentUser = authModel.currentUser;
    final trimmedDisplayName = _displayNameController.text.trim();
    final body = <String, dynamic>{
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'avatar': _avatarController.text.trim(),
    };

    if (trimmedDisplayName.isNotEmpty || currentUser?.nickname?.isNotEmpty == true) {
      body['displayName'] = trimmedDisplayName;
    }

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
        final updatedUserJson = userJson is Map
            ? Map<String, dynamic>.from(userJson)
            : null;
        final updatedUsername = updatedUserJson?['username'] as String? ??
            _usernameController.text.trim();

        if (token != null) {
          await authModel.loginWithToken(
            token,
            updatedUsername,
            userJson: updatedUserJson,
          );
        } else {
          await authModel.refreshUserInfo();
        }
        await LeaderboardModel.clearCache();

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
        final serverError = (data['error'] ?? '更新失败').toString();
        final reportRef = await _autoReportProfileFailure(
          source: 'EditProfileScreen._saveProfile.response',
          statusCode: response.statusCode,
          serverError: serverError,
          responseBodyPreview: response.body,
        );
        final message = reportRef == null
            ? serverError
            : '$serverError，已自动提交诊断 $reportRef';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final reportRef = await _autoReportProfileFailure(
        source: 'EditProfileScreen._saveProfile.exception',
        error: e,
        stackTrace: stackTrace,
      );
      final message = reportRef == null
          ? '更新失败: $e'
          : '更新失败: $e，已自动提交诊断 $reportRef';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final fallbackName = user?.displayName ?? user?.username ?? '';

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
                          (fallbackName.isNotEmpty ? fallbackName[0] : '?')
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
            '点击从本地选择头像，过大的图片会自动压缩',
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
    final currentDisplayName = user?.displayName ?? user?.username ?? '未设置';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildFormItem(
            label: '显示名称',
            child: TextFormField(
              controller: _displayNameController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: user?.nickname?.isNotEmpty == true
                    ? '请输入对外显示的名称'
                    : '当前对外显示: $currentDisplayName',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ),
          _divider(),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '昵称用于主页展示；用户名用于登录和账号标识，并且一年只能修改一次。',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          _divider(),
          _buildInfoItem(
            label: '学号',
            value: user?.userNo?.toString() ?? '未生成',
            showArrow: false,
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
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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

  Widget _divider() => const Divider(
    color: Colors.white10,
    height: 1,
    indent: 16,
    endIndent: 16,
  );

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
