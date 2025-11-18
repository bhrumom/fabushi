import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../models/liked_item.dart';

class LikeService extends ChangeNotifier {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  final Map<String, LikedItem> _likedItems = {};
  final Map<String, int> _likeCounts = {};
  bool _isInitialized = false;
  String? _authToken;
  
  bool get isInitialized => _isInitialized;

  static const String _storageKey = 'liked_items';

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadLikedItems();
    _isInitialized = true;
    notifyListeners(); // 确保UI更新
  }

  Future<void> _loadLikedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _likedItems.clear();
        for (var json in jsonList) {
          final item = LikedItem.fromJson(json);
          _likedItems[item.id] = item;
        }
      }
    } catch (e) {
      debugPrint('加载点赞数据失败: $e');
    }
  }

  Future<void> _saveLikedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _likedItems.values.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存点赞数据失败: $e');
    }
  }

  bool isLiked(String id) => _likedItems.containsKey(id);

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<void> toggleLike(LikedItem item) async {
    final wasLiked = _likedItems.containsKey(item.id);
    
    if (wasLiked) {
      _likedItems.remove(item.id);
      _likeCounts[item.id] = (_likeCounts[item.id] ?? 1) - 1;
    } else {
      _likedItems[item.id] = item;
      _likeCounts[item.id] = (_likeCounts[item.id] ?? 0) + 1;
    }
    
    await _saveLikedItems();
    notifyListeners();

    // 同步到云端
    _syncToCloud(item.id, item.contentType, wasLiked ? 'unlike' : 'like');
  }

  Future<void> _syncToCloud(String contentId, String contentType, String action) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/likes/toggle'),
        headers: headers,
        body: jsonEncode({
          'contentId': contentId,
          'contentType': contentType,
          'action': action,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _likeCounts[contentId] = data['likeCount'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('同步点赞失败: $e');
    }
  }

  Future<void> fetchLikeCounts(List<String> contentIds) async {
    if (contentIds.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/likes/batch-counts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contentIds': contentIds}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final counts = data['likeCounts'] as Map<String, dynamic>;
        counts.forEach((key, value) {
          _likeCounts[key] = value as int;
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('获取点赞数失败: $e');
    }
  }

  int getLikeCount(String contentId) => _likeCounts[contentId] ?? 0;

  List<LikedItem> getLikedItems() {
    final items = _likedItems.values.toList();
    items.sort((a, b) => b.likedAt.compareTo(a.likedAt));
    return items;
  }

  int get likedCount => _likedItems.length;

  LikedItem? getLikedItem(String id) => _likedItems[id];
}
