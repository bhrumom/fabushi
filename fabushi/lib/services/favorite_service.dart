import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../models/favorite_item.dart';

class FavoriteService extends ChangeNotifier {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  final Map<String, FavoriteItem> _favoritedItems = {};
  bool _isInitialized = false;
  String? _authToken;
  String? _currentUserId;

  bool get isInitialized => _isInitialized;

  String _getStorageKey() => 'favorited_items_${_currentUserId ?? "guest"}';

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<void> initialize({String? userId}) async {
    if (userId != null && userId != _currentUserId) {
      _currentUserId = userId;
      _favoritedItems.clear();
      await _loadFavoritedItems();
      await _syncFromCloud();
      _isInitialized = true;
      notifyListeners();
    } else if (!_isInitialized) {
      _currentUserId = userId;
      await _loadFavoritedItems();
      await _syncFromCloud();
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadFavoritedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_getStorageKey());
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _favoritedItems.clear();
        for (var json in jsonList) {
          final item = FavoriteItem.fromJson(json);
          _favoritedItems[item.id] = item;
        }
      }
    } catch (e) {
      debugPrint('加载收藏数据失败: $e');
    }
  }

  Future<void> _saveFavoritedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favoritedItems.values
          .map((item) => item.toJson())
          .toList();
      await prefs.setString(_getStorageKey(), jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存收藏数据失败: $e');
    }
  }

  bool isFavorited(String id) => _favoritedItems.containsKey(id);

  Future<void> clearUserData() async {
    _favoritedItems.clear();
    _currentUserId = null;
    _isInitialized = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(FavoriteItem item) async {
    final wasFavorited = _favoritedItems.containsKey(item.id);

    if (wasFavorited) {
      _favoritedItems.remove(item.id);
    } else {
      _favoritedItems[item.id] = item;
    }

    await _saveFavoritedItems();
    notifyListeners();

    // 同步到云端
    _syncToCloud(
      item.id,
      item.contentType,
      wasFavorited ? 'unfavorite' : 'favorite',
      title: item.title,
      filePath: item.filePath,
      description: item.description,
    );
  }

  Future<void> _syncFromCloud() async {
    if (_authToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/api/favorites/my-favorites'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['favorites'] != null) {
          final List<dynamic> favorites = data['favorites'];
          for (var fav in favorites) {
            final item = FavoriteItem.fromJson(fav);
            _favoritedItems[item.id] = item;
          }
          await _saveFavoritedItems();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('从云端加载收藏数据失败: $e');
    }
  }

  Future<void> _syncToCloud(
    String contentId,
    String contentType,
    String action, {
    String? title,
    String? filePath,
    String? description,
  }) async {
    if (_authToken == null) return;

    try {
      final body = {
        'contentId': contentId,
        'contentType': contentType,
        'action': action,
      };

      if (action == 'favorite') {
        if (title != null) body['title'] = title;
        if (filePath != null) body['filePath'] = filePath;
        if (description != null) body['description'] = description;
      }

      await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/favorites/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('同步收藏失败: $e');
    }
  }

  List<FavoriteItem> getFavoritedItems() {
    final items = _favoritedItems.values.toList();
    items.sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
    return items;
  }

  int get favoritedCount => _favoritedItems.length;

  FavoriteItem? getFavoritedItem(String id) => _favoritedItems[id];
}
