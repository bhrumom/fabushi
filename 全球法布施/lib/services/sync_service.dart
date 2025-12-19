import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import 'http_service.dart';

/// 同步服务 - 统一管理所有用户数据的云端同步
/// 
/// 设计原则:
/// 1. 云端为单一数据源
/// 2. 使用 syncVersion 进行增量同步
/// 3. 支持冲突检测（乐观锁）
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // 本地同步状态
  int _lastSyncVersion = 0;
  DateTime? _lastSyncAt;
  bool _isSyncing = false;
  String? _syncError;

  // Getters
  int get lastSyncVersion => _lastSyncVersion;
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  bool get hasSyncError => _syncError != null;

  static const String _syncVersionKey = 'sync_version';
  static const String _lastSyncAtKey = 'last_sync_at';

  /// 初始化同步服务
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSyncVersion = prefs.getInt(_syncVersionKey) ?? 0;
      final lastSyncAtStr = prefs.getString(_lastSyncAtKey);
      if (lastSyncAtStr != null) {
        _lastSyncAt = DateTime.tryParse(lastSyncAtStr);
      }
      debugPrint('📦 SyncService初始化完成: version=$_lastSyncVersion');
    } catch (e) {
      debugPrint('❌ SyncService初始化失败: $e');
    }
  }

  /// 从云端拉取数据（增量同步）
  Future<SyncResult> pullFromCloud() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: '正在同步中');
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final response = await HttpService.get(
        '${AppConfig.apiUrl}/api/sync?since=$_lastSyncVersion',
        useAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final syncData = SyncData.fromJson(data['data']);
          final newVersion = data['syncVersion'] as int;

          // 处理同步数据
          await _processSyncData(syncData);

          // 更新本地同步版本
          _lastSyncVersion = newVersion;
          _lastSyncAt = DateTime.now();
          await _saveSyncState();

          debugPrint('✅ 云端同步完成: version=$newVersion');
          return SyncResult(
            success: true,
            message: '同步成功',
            newVersion: newVersion,
            data: syncData,
          );
        }
      }

      _syncError = '同步失败: ${response.statusCode}';
      return SyncResult(success: false, message: _syncError!);
    } catch (e) {
      _syncError = '同步错误: $e';
      debugPrint('❌ 同步失败: $e');
      return SyncResult(success: false, message: _syncError!);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// 推送本地变更到云端
  Future<SyncResult> pushChanges(List<SyncChange> changes) async {
    if (changes.isEmpty) {
      return SyncResult(success: true, message: '无需同步');
    }

    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/sync',
        body: {
          'changes': changes.map((c) => c.toJson()).toList(),
        },
        useAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final hasConflicts = data['hasConflicts'] == true;
          final conflicts = (data['conflicts'] as List?)
              ?.map((c) => SyncConflict.fromJson(c))
              .toList() ?? [];

          if (hasConflicts) {
            debugPrint('⚠️ 同步存在冲突: ${conflicts.length}个');
            return SyncResult(
              success: true,
              message: '同步完成，存在冲突',
              conflicts: conflicts,
            );
          }

          debugPrint('✅ 推送同步完成');
          return SyncResult(success: true, message: '同步成功');
        }
      }

      return SyncResult(success: false, message: '推送失败: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ 推送同步失败: $e');
      return SyncResult(success: false, message: '推送错误: $e');
    }
  }

  /// 获取云端同步状态
  Future<void> fetchSyncState() async {
    try {
      final response = await HttpService.get(
        '${AppConfig.apiUrl}/api/sync/state',
        useAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final serverVersion = data['lastSyncVersion'] as int? ?? 0;
          if (serverVersion > _lastSyncVersion) {
            debugPrint('📤 云端有新数据: server=$serverVersion, local=$_lastSyncVersion');
            // 自动拉取新数据
            await pullFromCloud();
          }
        }
      }
    } catch (e) {
      debugPrint('获取同步状态失败: $e');
    }
  }

  /// 执行全量同步（先拉后推）
  Future<SyncResult> fullSync() async {
    debugPrint('🔄 开始全量同步...');
    
    // 1. 先从云端拉取
    final pullResult = await pullFromCloud();
    if (!pullResult.success) {
      return pullResult;
    }

    // 2. 推送本地待同步的变更
    final pendingChanges = await _getPendingChanges();
    if (pendingChanges.isNotEmpty) {
      final pushResult = await pushChanges(pendingChanges);
      if (!pushResult.success) {
        return pushResult;
      }
    }

    debugPrint('✅ 全量同步完成');
    return SyncResult(success: true, message: '全量同步完成');
  }

  /// 清除本地同步状态（登出时调用）
  Future<void> clearSyncState() async {
    _lastSyncVersion = 0;
    _lastSyncAt = null;
    _syncError = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncVersionKey);
    await prefs.remove(_lastSyncAtKey);
    
    notifyListeners();
    debugPrint('🗑️ 同步状态已清除');
  }

  // ============= 私有方法 =============

  Future<void> _saveSyncState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncVersionKey, _lastSyncVersion);
    if (_lastSyncAt != null) {
      await prefs.setString(_lastSyncAtKey, _lastSyncAt!.toIso8601String());
    }
  }

  Future<void> _processSyncData(SyncData data) async {
    // 处理点赞数据
    for (final like in data.likes) {
      debugPrint('同步点赞: ${like['content_id']}');
      // 这里可以更新本地缓存
    }

    // 处理评论数据
    for (final comment in data.comments) {
      debugPrint('同步评论: ${comment['id']}');
    }

    // 处理修行记录
    for (final record in data.meditationRecords) {
      debugPrint('同步修行记录: ${record['id']}');
    }

    // 处理修行目标
    for (final goal in data.meditationGoals) {
      debugPrint('同步修行目标: ${goal['id']}');
    }

    // 处理关注关系
    for (final follow in data.follows) {
      debugPrint('同步关注: ${follow['following_username']}');
    }
  }

  Future<List<SyncChange>> _getPendingChanges() async {
    // 获取本地待同步的变更
    // 这里可以从本地数据库或缓存中读取
    return [];
  }
}

/// 同步结果
class SyncResult {
  final bool success;
  final String message;
  final int? newVersion;
  final SyncData? data;
  final List<SyncConflict> conflicts;

  SyncResult({
    required this.success,
    required this.message,
    this.newVersion,
    this.data,
    this.conflicts = const [],
  });

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// 同步数据
class SyncData {
  final List<Map<String, dynamic>> likes;
  final List<Map<String, dynamic>> comments;
  final List<Map<String, dynamic>> meditationRecords;
  final List<Map<String, dynamic>> meditationGoals;
  final List<Map<String, dynamic>> follows;

  SyncData({
    required this.likes,
    required this.comments,
    required this.meditationRecords,
    required this.meditationGoals,
    required this.follows,
  });

  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData(
      likes: List<Map<String, dynamic>>.from(json['likes'] ?? []),
      comments: List<Map<String, dynamic>>.from(json['comments'] ?? []),
      meditationRecords: List<Map<String, dynamic>>.from(json['meditationRecords'] ?? []),
      meditationGoals: List<Map<String, dynamic>>.from(json['meditationGoals'] ?? []),
      follows: List<Map<String, dynamic>>.from(json['follows'] ?? []),
    );
  }

  bool get isEmpty =>
      likes.isEmpty &&
      comments.isEmpty &&
      meditationRecords.isEmpty &&
      meditationGoals.isEmpty &&
      follows.isEmpty;
}

/// 同步变更
class SyncChange {
  final String table;
  final String action; // 'insert', 'update', 'delete'
  final Map<String, dynamic> data;
  final int? clientVersion;

  SyncChange({
    required this.table,
    required this.action,
    required this.data,
    this.clientVersion,
  });

  Map<String, dynamic> toJson() => {
    'table': table,
    'action': action,
    'data': data,
    'clientVersion': clientVersion,
  };
}

/// 同步冲突
class SyncConflict {
  final String table;
  final int recordId;
  final int serverVersion;

  SyncConflict({
    required this.table,
    required this.recordId,
    required this.serverVersion,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      table: json['table'] as String,
      recordId: json['recordId'] as int,
      serverVersion: json['serverVersion'] as int,
    );
  }
}
