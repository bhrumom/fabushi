import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

/// 用户屏蔽服务
///
/// 管理用户屏蔽列表，屏蔽后将移除该用户的所有内容
class UserBlockService {
  static final UserBlockService _instance = UserBlockService._();
  factory UserBlockService() => _instance;
  UserBlockService._();

  static const String _blockedUsersKey = 'blocked_users';

  /// 内存中的屏蔽列表缓存
  Set<String> _blockedUsers = {};
  bool _loaded = false;

  /// 初始化/加载屏蔽列表
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blockedUsersKey) ?? [];
    _blockedUsers = list.toSet();
    _loaded = true;
  }

  /// 屏蔽用户
  ///
  /// [userId] 要屏蔽的用户 ID
  /// [reason] 屏蔽原因（可选）
  Future<bool> blockUser(String userId, {String? reason}) async {
    await _ensureLoaded();

    // 本地添加
    _blockedUsers.add(userId);
    await _saveBlockedUsers();

    // 通知后端
    try {
      await _notifyBackend(userId, blocked: true, reason: reason);
    } catch (e) {
      debugPrint('⚠️ 通知后端屏蔽失败: $e');
    }

    debugPrint('✅ 已屏蔽用户: $userId');
    return true;
  }

  /// 取消屏蔽用户
  Future<bool> unblockUser(String userId) async {
    await _ensureLoaded();

    _blockedUsers.remove(userId);
    await _saveBlockedUsers();

    try {
      await _notifyBackend(userId, blocked: false);
    } catch (e) {
      debugPrint('⚠️ 通知后端取消屏蔽失败: $e');
    }

    debugPrint('✅ 已取消屏蔽用户: $userId');
    return true;
  }

  /// 检查用户是否被屏蔽
  Future<bool> isBlocked(String userId) async {
    await _ensureLoaded();
    return _blockedUsers.contains(userId);
  }

  /// 获取所有被屏蔽的用户 ID
  Future<List<String>> getBlockedUsers() async {
    await _ensureLoaded();
    return _blockedUsers.toList();
  }

  /// 检查内容是否应被过滤（发布者被屏蔽）
  bool shouldFilter(String? authorId) {
    if (authorId == null) return false;
    return _blockedUsers.contains(authorId);
  }

  /// 保存屏蔽列表到本地
  Future<void> _saveBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedUsersKey, _blockedUsers.toList());
  }

  /// 通知后端屏蔽/取消屏蔽
  Future<void> _notifyBackend(String userId, {required bool blocked, String? reason}) async {
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/api/block-user');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'blocked_user_id': userId,
          'action': blocked ? 'block' : 'unblock',
          'reason': reason ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('后端通知失败: $e');
    }
  }
}
