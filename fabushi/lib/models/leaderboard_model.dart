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
  final int? totalCount;
  final int? totalDuration;
  final int totalDays;
  final String? latestSutra;
  final String? latestRecordDate;
  final int rank;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final bool isSelf;
  final Map<String, dynamic> privacy;

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
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isSelf = false,
    this.privacy = const {},
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      username: json['username'] ?? '',
      displayName:
          json['displayName'] ?? json['nickname'] ?? json['username'] ?? '',
      avatar: json['avatar'],
      totalBytes: _asInt(json['totalBytes']),
      totalRecords: _asInt(json['totalRecords']),
      totalCount: json.containsKey('totalCount') && json['totalCount'] != null
          ? _asInt(json['totalCount'])
          : null,
      totalDuration:
          json.containsKey('totalDuration') && json['totalDuration'] != null
          ? _asInt(json['totalDuration'])
          : null,
      totalDays: _asInt(json['totalDays']),
      latestSutra: json['latestSutra'],
      latestRecordDate: json['latestRecordDate'],
      rank: _asInt(json['rank']),
      followerCount: _asInt(json['followerCount'] ?? json['follower_count']),
      followingCount: _asInt(json['followingCount'] ?? json['following_count']),
      isFollowing: _asBool(json['isFollowing'] ?? json['is_following']),
      isSelf: _asBool(json['isSelf'] ?? json['is_self']),
      privacy: json['privacy'] is Map
          ? Map<String, dynamic>.from(json['privacy'] as Map)
          : const {},
    );
  }

  bool get isPracticePrivate =>
      _asBool(privacy['isPrivate'] ?? privacy['is_private']);
  bool get canShowPracticeName =>
      !isPracticePrivate &&
      _asBool(
        privacy['showPracticeName'] ?? privacy['show_practice_name'],
        fallback: true,
      );
  bool get canShowDuration =>
      !isPracticePrivate &&
      _asBool(
        privacy['showDuration'] ?? privacy['show_duration'],
        fallback: true,
      );
  bool get canShowChantCount =>
      !isPracticePrivate &&
      _asBool(
        privacy['showChantCount'] ?? privacy['show_chant_count'],
        fallback: true,
      );

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == 'true' || value == '1';
    return fallback;
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
    'followerCount': followerCount,
    'followingCount': followingCount,
    'isFollowing': isFollowing,
    'isSelf': isSelf,
    'privacy': privacy,
  };
}

class LeaderboardModel extends ChangeNotifier {
  static const _cacheKey = 'global_leaderboard_cache_v3';
  static const _timestampKey = 'global_leaderboard_timestamp_v3';

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
      final cached = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_timestampKey);

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
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('保存缓存失败: $e');
    }
  }
}
