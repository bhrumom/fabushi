import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import 'http_service.dart';

abstract class SocialHttpClient {
  Future<http.Response> get(
    String url, {
    Map<String, String>? queryParams,
    bool useAuth = false,
  });

  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  });
}

class DefaultSocialHttpClient implements SocialHttpClient {
  @override
  Future<http.Response> get(
    String url, {
    Map<String, String>? queryParams,
    bool useAuth = false,
  }) {
    return HttpService.get(
      url,
      queryParams: queryParams,
      useAuth: useAuth,
    );
  }

  @override
  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) {
    return HttpService.post(url, body: body, useAuth: useAuth);
  }
}

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;

  SocialService._internal() : _httpClient = DefaultSocialHttpClient();

  SocialService.withClient(SocialHttpClient httpClient)
    : _httpClient = httpClient;

  final SocialHttpClient _httpClient;

  String get _baseUrl => '${AppConfig.currentBackendUrl}/api/social';

  bool _isSuccessStatus(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Map<String, dynamic>? _tryParseBodyAsMap(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);
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

  Map<String, dynamic> _buildFailurePayload(http.Response response) {
    final parsed = _tryParseBodyAsMap(response);
    final payload = <String, dynamic>{
      'success': false,
      'error': HttpService.getErrorMessage(response),
      'statusCode': response.statusCode,
    };

    final errorKey = parsed?['errorKey'] ?? parsed?['code'];
    if (errorKey is String && errorKey.isNotEmpty) {
      payload['errorKey'] = errorKey;
    }

    return payload;
  }

  Future<Map<String, dynamic>?> toggleFollow(String username) async {
    final response = await _httpClient.post(
      '$_baseUrl/follow/toggle',
      body: {'username': username},
      useAuth: true,
    );
    final data = _tryParseBodyAsMap(response);
    if (_isSuccessStatus(response) && data != null && data['success'] == true) {
      return data;
    }
    if (data != null) {
      return _buildFailurePayload(response);
    }
    return {
      'success': false,
      'error': '服务器响应格式错误',
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> fetchFollowSummary({String? username}) async {
    final uri = Uri.parse('$_baseUrl/follow-summary').replace(
      queryParameters: username == null ? null : {'username': username},
    );
    final response = await _httpClient.get(uri.toString(), useAuth: true);
    final data = _tryParseBodyAsMap(response);
    if (response.statusCode == 200 && data != null) {
      return data;
    }
    if (data != null) {
      return _buildFailurePayload(response);
    }
    return {
      'success': false,
      'error': '服务器响应格式错误',
      'statusCode': response.statusCode,
    };
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
    final response = await _httpClient.get(uri.toString(), useAuth: true);
    final data = _tryParseBodyAsMap(response);
    if (response.statusCode == 200 && data != null) {
      final users = data['users'];
      if (users is List) {
        return List<Map<String, dynamic>>.from(users);
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchPracticePrivacy() async {
    final response = await _httpClient.get(
      '$_baseUrl/practice-privacy',
      useAuth: true,
    );
    final data = _tryParseBodyAsMap(response);
    if (response.statusCode == 200 && data != null) {
      final privacy = data['privacy'];
      if (privacy is Map) {
        return Map<String, dynamic>.from(privacy);
      }
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
    final response = await _httpClient.post(
      '$_baseUrl/practice-privacy',
      body: {
        'isPrivate': isPrivate,
        'showPracticeName': showPracticeName,
        'showDuration': showDuration,
        'showChantCount': showChantCount,
      },
      useAuth: true,
    );
    final data = _tryParseBodyAsMap(response);
    if (response.statusCode != 200 || data == null) {
      return false;
    }
    return data['success'] == true;
  }
}
