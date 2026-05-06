import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../models/co_practice_group_model.dart';
import 'app_settings.dart';

class CoPracticeGroupCreationResult {
  final int? groupId;
  final String? errorMessage;
  final int? statusCode;

  const CoPracticeGroupCreationResult._({
    this.groupId,
    this.errorMessage,
    this.statusCode,
  });

  const CoPracticeGroupCreationResult.success(int groupId)
    : this._(groupId: groupId);

  const CoPracticeGroupCreationResult.failure(
    String errorMessage, {
    int? statusCode,
  }) : this._(errorMessage: errorMessage, statusCode: statusCode);

  bool get isSuccess => groupId != null;
}

class CoPracticeService {
  static final CoPracticeService _instance = CoPracticeService._internal();
  factory CoPracticeService({
    http.Client? httpClient,
    Future<String> Function()? baseUrlResolver,
    Future<Map<String, String>> Function()? headersResolver,
  }) {
    if (httpClient != null ||
        baseUrlResolver != null ||
        headersResolver != null) {
      return CoPracticeService._internal(
        httpClient: httpClient,
        baseUrlResolver: baseUrlResolver,
        headersResolver: headersResolver,
      );
    }
    return _instance;
  }

  CoPracticeService._internal({
    http.Client? httpClient,
    Future<String> Function()? baseUrlResolver,
    Future<Map<String, String>> Function()? headersResolver,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrlResolver = baseUrlResolver ?? AppSettings.getBackendUrl,
       _headersResolver = headersResolver;

  final http.Client _httpClient;
  final Future<String> Function() _baseUrlResolver;
  final Future<Map<String, String>> Function()? _headersResolver;

  Future<String> get _baseUrl async => _baseUrlResolver();

  Future<Map<String, String>> _headers() async {
    if (_headersResolver != null) {
      return _headersResolver!();
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.tokenStorageKey);
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<CoPracticeGroup>> searchGroups({
    String query = '',
    int limit = 30,
  }) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse(
      '$baseUrl/api/meditation/groups',
    ).replace(queryParameters: {'query': query, 'limit': limit.toString()});
    final response = await _httpClient.get(uri, headers: await _headers());
    if (response.statusCode != 200) return [];

    final data = _decodeJsonMap(response.body);
    if (data['success'] != true) return [];

    final groups = data['data']?['groups'] as List<dynamic>? ?? [];
    return groups
        .map(
          (item) =>
              CoPracticeGroup.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<CoPracticeGroupCreationResult> createGroup({
    required String name,
    String description = '',
    required bool requireApproval,
    required int dailyGoalMinutes,
    required int cumulativeMissLimit,
    required int consecutiveMissLimit,
  }) async {
    try {
      final baseUrl = await _baseUrl;
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/meditation/groups'),
        headers: await _headers(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'requireApproval': requireApproval,
          'dailyGoalMinutes': dailyGoalMinutes,
          'cumulativeMissLimit': cumulativeMissLimit,
          'consecutiveMissLimit': consecutiveMissLimit,
        }),
      );

      final data = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || data['success'] != true) {
        return CoPracticeGroupCreationResult.failure(
          _extractErrorMessage(data, fallback: '创建共修小组失败'),
          statusCode: response.statusCode,
        );
      }

      final id = data['data']?['groupId'];
      if (id is int) {
        return CoPracticeGroupCreationResult.success(id);
      }

      final parsedId = int.tryParse(id?.toString() ?? '');
      if (parsedId != null) {
        return CoPracticeGroupCreationResult.success(parsedId);
      }

      return const CoPracticeGroupCreationResult.failure('创建成功，但未返回小组编号');
    } catch (_) {
      return const CoPracticeGroupCreationResult.failure(
        '创建共修小组失败，请检查网络后重试',
      );
    }
  }

  Future<String?> joinGroup(int groupId) async {
    final baseUrl = await _baseUrl;
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/api/meditation/groups/join'),
      headers: await _headers(),
      body: jsonEncode({'groupId': groupId}),
    );

    if (response.statusCode != 200) return null;
    final data = _decodeJsonMap(response.body);
    if (data['success'] != true) return null;
    return data['data']?['message']?.toString() ?? '已提交';
  }

  Future<CoPracticeGroupDetail?> fetchGroupDetail(int groupId) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse(
      '$baseUrl/api/meditation/groups/detail',
    ).replace(queryParameters: {'groupId': groupId.toString()});
    final response = await _httpClient.get(uri, headers: await _headers());
    if (response.statusCode != 200) return null;

    final data = _decodeJsonMap(response.body);
    if (data['success'] != true) return null;
    return CoPracticeGroupDetail.fromJson(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<bool> reviewJoinRequest({
    required int groupId,
    required String username,
    required bool approve,
  }) async {
    final baseUrl = await _baseUrl;
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/api/meditation/groups/review'),
      headers: await _headers(),
      body: jsonEncode({
        'groupId': groupId,
        'username': username,
        'approve': approve,
      }),
    );

    if (response.statusCode != 200) return false;
    final data = _decodeJsonMap(response.body);
    return data['success'] == true;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }

  String _extractErrorMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message = data['error'] ?? data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return fallback;
  }
}
