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
  String? _currentUserId;
  
  bool get isInitialized => _isInitialized;

  String _getStorageKey() => 'liked_items_${_currentUserId ?? "guest"}';

  Future<void> initialize({String? userId}) async {
    if (userId != null && userId != _currentUserId) {
      _currentUserId = userId;
      _likedItems.clear();
      _likeCounts.clear();
      await _loadLikedItems();
      await _syncFromCloud();
      _isInitialized = true;
      notifyListeners();
    } else if (!_isInitialized) {
      _currentUserId = userId;
      await _loadLikedItems();
      await _syncFromCloud();
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadLikedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_getStorageKey());
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
      await prefs.setString(_getStorageKey(), jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存点赞数据失败: $e');
    }
  }

  bool isLiked(String id) => _likedItems.containsKey(id);

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<void> clearUserData() async {
    _likedItems.clear();
    _likeCounts.clear();
    _currentUserId = null;
    _isInitialized = false;
    notifyListeners();
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

    // 同步到云端，点赞时额外发送标题和文件路径
    _syncToCloud(
      item.id, 
      item.contentType, 
      wasLiked ? 'unlike' : 'like',
      title: item.username,  // username 字段存储的是标题
      filePath: item.filePath,
    );
  }

  Future<void> _syncFromCloud() async {
    if (_authToken == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/api/likes/my-likes'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['likes'] != null) {
          final List<dynamic> likes = data['likes'];
          for (var like in likes) {
            final item = LikedItem.fromJson(like);
            _likedItems[item.id] = item;
          }
          await _saveLikedItems();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('从云端加载点赞数据失败: $e');
    }
  }

  Future<void> _syncToCloud(String contentId, String contentType, String action, {String? title, String? filePath}) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final body = {
        'contentId': contentId,
        'contentType': contentType,
        'action': action,
      };
      
      // 点赞时额外发送标题和文件路径
      if (action == 'like') {
        if (title != null) body['title'] = title;
        if (filePath != null) body['filePath'] = filePath;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/likes/toggle'),
        headers: headers,
        body: jsonEncode(body),
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

  // 获取用户评论被点赞的总数（用于"获赞"统计）
  int _receivedLikeCount = 0;
  int get receivedLikeCount => _receivedLikeCount;

  Future<void> fetchReceivedLikeCount() async {
    if (_authToken == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/api/likes/received-count'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _receivedLikeCount = data['receivedLikeCount'] ?? 0;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('获取被点赞数失败: $e');
    }
  }
}
