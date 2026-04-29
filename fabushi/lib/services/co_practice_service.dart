import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../models/co_practice_group_model.dart';
import 'app_settings.dart';

class CoPracticeService {
  static final CoPracticeService _instance = CoPracticeService._internal();
  factory CoPracticeService() => _instance;
  CoPracticeService._internal();

  Future<String> get _baseUrl async => await AppSettings.getBackendUrl();

  Future<Map<String, String>> _headers() async {
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
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    if (data['success'] != true) return [];

    final groups = data['data']?['groups'] as List<dynamic>? ?? [];
    return groups
        .map(
          (item) =>
              CoPracticeGroup.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<int?> createGroup({
    required String name,
    String description = '',
    required bool requireApproval,
    required int dailyGoalMinutes,
    required int cumulativeMissLimit,
    required int consecutiveMissLimit,
  }) async {
    final baseUrl = await _baseUrl;
    final response = await http.post(
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

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['success'] != true) return null;
    final id = data['data']?['groupId'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Future<String?> joinGroup(int groupId) async {
    final baseUrl = await _baseUrl;
    final response = await http.post(
      Uri.parse('$baseUrl/api/meditation/groups/join'),
      headers: await _headers(),
      body: jsonEncode({'groupId': groupId}),
    );

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['success'] != true) return null;
    return data['data']?['message']?.toString() ?? '已提交';
  }

  Future<CoPracticeGroupDetail?> fetchGroupDetail(int groupId) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse(
      '$baseUrl/api/meditation/groups/detail',
    ).replace(queryParameters: {'groupId': groupId.toString()});
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/meditation/groups/review'),
      headers: await _headers(),
      body: jsonEncode({
        'groupId': groupId,
        'username': username,
        'approve': approve,
      }),
    );

    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body);
    return data['success'] == true;
  }
}
