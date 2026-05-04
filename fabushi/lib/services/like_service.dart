import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../models/liked_item.dart';

abstract class LikeHttpClient {
  Future<http.Response> get(Uri url, {Map<String, String>? headers});

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  });
}

class DefaultLikeHttpClient implements LikeHttpClient {
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return http.get(url, headers: headers);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(url, headers: headers, body: body);
  }
}

abstract class LikeStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SharedPreferencesLikeStorage implements LikeStorage {
  SharedPreferencesLikeStorage({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesProvider;

  @override
  Future<String?> read(String key) async {
    final prefs = await _preferencesProvider();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _preferencesProvider();
    await prefs.setString(key, value);
  }
}

class LikeService extends ChangeNotifier {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;

  LikeService._internal()
    : _httpClient = DefaultLikeHttpClient(),
      _storage = SharedPreferencesLikeStorage();

  LikeService.withDependencies({
    LikeHttpClient? httpClient,
    LikeStorage? storage,
  }) : _httpClient = httpClient ?? DefaultLikeHttpClient(),
       _storage = storage ?? SharedPreferencesLikeStorage();

  final LikeHttpClient _httpClient;
  final LikeStorage _storage;
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

  Map<String, dynamic>? _tryParseBodyAsMap(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _loadLikedItems() async {
    try {
      final jsonString = await _storage.read(_getStorageKey());
      if (jsonString == null || jsonString.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        return;
      }

      _likedItems.clear();
      for (final itemJson in decoded) {
        if (itemJson is! Map) {
          continue;
        }

        try {
          final item = LikedItem.fromJson(Map<String, dynamic>.from(itemJson));
          _likedItems[item.id] = item;
        } catch (e) {
          debugPrint('跳过格式错误的点赞缓存数据: $e');
        }
      }
    } catch (e) {
      debugPrint('加载点赞数据失败: $e');
    }
  }

  Future<void> _saveLikedItems() async {
    try {
      final jsonList = _likedItems.values.map((item) => item.toJson()).toList();
      await _storage.write(_getStorageKey(), jsonEncode(jsonList));
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

    _syncToCloud(
      item.id,
      item.contentType,
      wasLiked ? 'unlike' : 'like',
      title: item.username,
      filePath: item.filePath,
    );
  }

  Future<void> _syncFromCloud() async {
    if (_authToken == null) return;

    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConfig.apiUrl}/api/likes/my-likes'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = _tryParseBodyAsMap(response.body);
      final likes = data?['likes'];
      if (data?['success'] != true || likes is! List) {
        return;
      }

      for (final like in likes) {
        if (like is! Map) {
          continue;
        }

        try {
          final item = LikedItem.fromJson(Map<String, dynamic>.from(like));
          _likedItems[item.id] = item;
        } catch (e) {
          debugPrint('跳过格式错误的云端点赞数据: $e');
        }
      }
      await _saveLikedItems();
      notifyListeners();
    } catch (e) {
      debugPrint('从云端加载点赞数据失败: $e');
    }
  }

  Future<void> _syncToCloud(
    String contentId,
    String contentType,
    String action, {
    String? title,
    String? filePath,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final body = <String, dynamic>{
        'contentId': contentId,
        'contentType': contentType,
        'action': action,
      };

      if (action == 'like') {
        if (title != null) {
          body['title'] = title;
        }
        if (filePath != null) {
          body['filePath'] = filePath;
        }
      }

      final response = await _httpClient.post(
        Uri.parse('${AppConfig.apiUrl}/api/likes/toggle'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = _tryParseBodyAsMap(response.body);
      final likeCount = data?['likeCount'];
      if (likeCount is num) {
        _likeCounts[contentId] = likeCount.toInt();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('同步点赞失败: $e');
    }
  }

  Future<void> fetchLikeCounts(List<String> contentIds) async {
    if (contentIds.isEmpty) return;

    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.apiUrl}/api/likes/batch-counts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contentIds': contentIds}),
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = _tryParseBodyAsMap(response.body);
      final counts = data?['likeCounts'];
      if (counts is! Map) {
        return;
      }

      counts.forEach((key, value) {
        if (value is num) {
          _likeCounts[key.toString()] = value.toInt();
        }
      });
      notifyListeners();
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

  int _receivedLikeCount = 0;
  int get receivedLikeCount => _receivedLikeCount;

  Future<void> fetchReceivedLikeCount() async {
    if (_authToken == null) return;

    try {
      final response = await _httpClient.get(
        Uri.parse('${AppConfig.apiUrl}/api/likes/received-count'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = _tryParseBodyAsMap(response.body);
      final receivedLikeCount = data?['receivedLikeCount'];
      if (data?['success'] == true && receivedLikeCount is num) {
        _receivedLikeCount = receivedLikeCount.toInt();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('获取被点赞数失败: $e');
    }
  }
}
