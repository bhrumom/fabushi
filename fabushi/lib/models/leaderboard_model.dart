import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/leaderboard_service.dart';

class LeaderboardEntry {
  final String username;
  final String displayName;
  final String? avatar;
  final int totalBytes;
  final int totalRecords;
  final int totalCount;
  final int totalDuration;
  final int totalDays;
  final String? latestSutra;
  final String? latestRecordDate;
  final int rank;

  LeaderboardEntry({
    required this.username,
    required this.displayName,
    this.avatar,
    required this.totalBytes,
    required this.totalRecords,
    required this.totalCount,
    required this.totalDuration,
    required this.totalDays,
    this.latestSutra,
    this.latestRecordDate,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      username: json['username'] ?? '',
      displayName:
          json['displayName'] ?? json['nickname'] ?? json['username'] ?? '',
      avatar: json['avatar'],
      totalBytes: json['totalBytes'] ?? 0,
      totalRecords: json['totalRecords'] ?? 0,
      totalCount: json['totalCount'] ?? 0,
      totalDuration: json['totalDuration'] ?? 0,
      totalDays: json['totalDays'] ?? 0,
      latestSutra: json['latestSutra'],
      latestRecordDate: json['latestRecordDate'],
      rank: json['rank'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'displayName': displayName,
    'avatar': avatar,
    'totalBytes': totalBytes,
    'totalRecords': totalRecords,
    'totalCount': totalCount,
    'totalDuration': totalDuration,
    'totalDays': totalDays,
    'latestSutra': latestSutra,
    'latestRecordDate': latestRecordDate,
    'rank': rank,
  };
}

class LeaderboardModel extends ChangeNotifier {
  final LeaderboardService _service = LeaderboardService();
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdateTime;
  DateTime? _lastRefreshTime;
  bool _hasLoadedCache = false;

  List<LeaderboardEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  Future<void> fetchLeaderboard({bool forceRefresh = false}) async {
    // 首次加载缓存
    if (!_hasLoadedCache) {
      await _loadCache();
      _hasLoadedCache = true;
      if (_entries.isNotEmpty) {
        notifyListeners();
      }
    }

    // 检查缓存（1天）
    if (!forceRefresh && _lastUpdateTime != null && _entries.isNotEmpty) {
      final diff = DateTime.now().difference(_lastUpdateTime!);
      if (diff.inDays < 1) {
        return; // 使用缓存，不需要刷新
      }
    }

    // 检查刷新限制（1分钟）- 只在真正需要网络请求时才检查
    if (_lastRefreshTime != null) {
      final diff = DateTime.now().difference(_lastRefreshTime!);
      if (diff.inSeconds < 60) {
        _error = '刷新过于频繁，请${60 - diff.inSeconds}秒后再试';
        notifyListeners();
        // 3秒后自动清除错误消息
        Future.delayed(const Duration(seconds: 3), () {
          if (_error?.contains('刷新过于频繁') == true) {
            _error = null;
            notifyListeners();
          }
        });
        return;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _service.fetchLeaderboard();
      _entries = data.map((json) => LeaderboardEntry.fromJson(json)).toList();
      _lastUpdateTime = DateTime.now();
      _lastRefreshTime = DateTime.now();

      await _saveCache();
    } catch (e) {
      _error = '获取排行榜失败: $e';
      if (_entries.isEmpty) {
        _entries = [];
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('leaderboard_cache');
      final timestamp = prefs.getInt('leaderboard_timestamp');

      if (cached != null && timestamp != null) {
        final data = jsonDecode(cached) as List;
        _entries = data.map((json) => LeaderboardEntry.fromJson(json)).toList();
        _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('加载缓存失败: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _entries.map((e) => e.toJson()).toList();
      await prefs.setString('leaderboard_cache', jsonEncode(data));
      await prefs.setInt(
        'leaderboard_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('保存缓存失败: $e');
    }
  }
}
