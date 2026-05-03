import 'dart:convert';

import '../core/config/app_config.dart';
import 'http_service.dart';

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  String get _baseUrl => '${AppConfig.currentBackendUrl}/api/social';

  Future<Map<String, dynamic>?> toggleFollow(String username) async {
    final response = await HttpService.post(
      '$_baseUrl/follow/toggle',
      body: {'username': username},
      useAuth: true,
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchFollowSummary({String? username}) async {
    final uri = Uri.parse('$_baseUrl/follow-summary').replace(
      queryParameters: username == null ? null : {'username': username},
    );
    final response = await HttpService.get(uri.toString(), useAuth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'success': false};
  }

  Future<List<Map<String, dynamic>>> fetchFollowList({
    required String type,
    String? username,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'type': type,
      'limit': '$limit',
      'offset': '$offset',
      if (username != null) 'username': username,
    };
    final uri = Uri.parse('$_baseUrl/follows').replace(queryParameters: params);
    final response = await HttpService.get(uri.toString(), useAuth: true);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final users = data['users'];
      if (users is List) return List<Map<String, dynamic>>.from(users);
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchPracticePrivacy() async {
    final response = await HttpService.get('$_baseUrl/practice-privacy', useAuth: true);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(data['privacy'] ?? {});
    }
    return {
      'isPrivate': false,
      'showPracticeName': true,
      'showDuration': true,
      'showChantCount': true,
    };
  }

  Future<bool> updatePracticePrivacy({
    required bool isPrivate,
    required bool showPracticeName,
    required bool showDuration,
    required bool showChantCount,
  }) async {
    final response = await HttpService.post(
      '$_baseUrl/practice-privacy',
      body: {
        'isPrivate': isPrivate,
        'showPracticeName': showPracticeName,
        'showDuration': showDuration,
        'showChantCount': showChantCount,
      },
      useAuth: true,
    );
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['success'] == true;
  }
}
