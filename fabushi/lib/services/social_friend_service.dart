import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'unified_api_service.dart';

class SocialFriendContact {
  const SocialFriendContact({
    required this.id,
    required this.displayName,
    this.username = '',
    this.avatarUrl = '',
    this.status = 'friend',
  });

  final String id;
  final String displayName;
  final String username;
  final String avatarUrl;
  final String status;

  factory SocialFriendContact.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['userId'] ?? json['uid'] ?? '').toString();
    final username = (json['username'] ?? json['userNo'] ?? '').toString();
    return SocialFriendContact(
      id: id.isEmpty ? username : id,
      displayName: (json['displayName'] ??
              json['nickname'] ??
              json['name'] ??
              username ??
              '大乘好友')
          .toString(),
      username: username,
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '').toString(),
      status: (json['status'] ?? 'friend').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'username': username,
        'avatarUrl': avatarUrl,
        'status': status,
      };
}

class SocialFriendRequest {
  const SocialFriendRequest({
    required this.id,
    required this.fromUser,
    required this.createdAt,
    this.message = '',
  });

  final String id;
  final SocialFriendContact fromUser;
  final DateTime createdAt;
  final String message;

  factory SocialFriendRequest.fromJson(Map<String, dynamic> json) {
    final userJson = json['fromUser'] is Map<String, dynamic>
        ? json['fromUser'] as Map<String, dynamic>
        : json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : json;
    return SocialFriendRequest(
      id: (json['id'] ?? json['requestId'] ?? '').toString(),
      fromUser: SocialFriendContact.fromJson(userJson),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      message: (json['message'] ?? '').toString(),
    );
  }
}

class SocialFriendService {
  SocialFriendService({UnifiedApiService? api}) : _api = api ?? UnifiedApiService();

  static const String _localFriendsKey = 'social_friends_cache_v1';
  static const String _pendingSentKey = 'social_friend_pending_sent_v1';

  final UnifiedApiService _api;

  Future<List<SocialFriendContact>> listFriends({String? token}) async {
    _api.initialize();
    try {
      final response = await _api.get(
        '/api/social/friends',
        headers: _authHeaders(token),
      );
      final payload = jsonDecode(response.body);
      final friends = _readList(payload)
          .whereType<Map<String, dynamic>>()
          .map(SocialFriendContact.fromJson)
          .where((friend) => friend.id.isNotEmpty)
          .toList();
      await _saveContacts(_localFriendsKey, friends);
      return friends;
    } catch (error) {
      debugPrint('加载好友列表失败，使用本地缓存: $error');
      return _loadContacts(_localFriendsKey);
    }
  }

  Future<List<SocialFriendContact>> searchUsers(
    String keyword, {
    String? token,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];
    _api.initialize();
    try {
      final response = await _api.get(
        '/api/social/users/search',
        queryParams: {'q': query},
        headers: _authHeaders(token),
      );
      final payload = jsonDecode(response.body);
      return _readList(payload)
          .whereType<Map<String, dynamic>>()
          .map(SocialFriendContact.fromJson)
          .where((user) => user.id.isNotEmpty)
          .toList();
    } catch (error) {
      debugPrint('搜索好友接口暂不可用: $error');
      final cached = await _loadContacts(_localFriendsKey);
      final lower = query.toLowerCase();
      return cached
          .where(
            (item) =>
                item.displayName.toLowerCase().contains(lower) ||
                item.username.toLowerCase().contains(lower),
          )
          .toList();
    }
  }

  Future<void> sendFriendRequest(
    SocialFriendContact user, {
    String? token,
    String message = '',
  }) async {
    if (user.id.isEmpty) return;
    _api.initialize();
    try {
      await _api.post(
        '/api/social/friend-requests',
        headers: _authHeaders(token),
        body: {
          'targetUserId': user.id,
          if (message.trim().isNotEmpty) 'message': message.trim(),
        },
      );
    } catch (error) {
      debugPrint('发送好友申请接口暂不可用，已保存为本地待发送: $error');
      await _appendContact(_pendingSentKey, user.copyWith(status: 'pending'));
    }
  }

  Future<List<SocialFriendRequest>> listIncomingRequests({String? token}) async {
    _api.initialize();
    try {
      final response = await _api.get(
        '/api/social/friend-requests/incoming',
        headers: _authHeaders(token),
      );
      final payload = jsonDecode(response.body);
      return _readList(payload)
          .whereType<Map<String, dynamic>>()
          .map(SocialFriendRequest.fromJson)
          .where((request) => request.id.isNotEmpty)
          .toList();
    } catch (error) {
      debugPrint('加载好友申请失败: $error');
      return const [];
    }
  }

  Future<void> acceptFriendRequest(String requestId, {String? token}) async {
    if (requestId.trim().isEmpty) return;
    _api.initialize();
    await _api.post(
      '/api/social/friend-requests/$requestId/accept',
      headers: _authHeaders(token),
    );
  }

  Map<String, String>? _authHeaders(String? token) {
    final value = token?.trim();
    if (value == null || value.isEmpty) return null;
    return {'Authorization': 'Bearer $value'};
  }

  List<dynamic> _readList(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) return data;
      if (data is Map<String, dynamic>) {
        final users = data['users'];
        if (users is List) return users;
        final friends = data['friends'];
        if (friends is List) return friends;
        final requests = data['requests'];
        if (requests is List) return requests;
      }
    }
    return const [];
  }

  Future<List<SocialFriendContact>> _loadContacts(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SocialFriendContact.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveContacts(
    String key,
    List<SocialFriendContact> contacts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(contacts.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _appendContact(String key, SocialFriendContact contact) async {
    final contacts = await _loadContacts(key);
    final next = [
      contact,
      ...contacts.where((item) => item.id != contact.id),
    ];
    await _saveContacts(key, next);
  }
}

extension on SocialFriendContact {
  SocialFriendContact copyWith({String? status}) {
    return SocialFriendContact(
      id: id,
      displayName: displayName,
      username: username,
      avatarUrl: avatarUrl,
      status: status ?? this.status,
    );
  }
}
