import 'dart:convert';
import '../core/config/app_config.dart';
import 'http_service.dart';

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final response = await HttpService.get(AppConfig.leaderboardUrl, useAuth: false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 即使后端返回错误，也尝试获取leaderboard字段
        if (data['leaderboard'] != null) {
          return List<Map<String, dynamic>>.from(data['leaderboard']);
        }
        // 如果有错误信息，记录但返回空数组
        if (data['error'] != null) {
          print('后端返回错误: ${data['error']} - ${data['message'] ?? ""}');
          return [];
        }
        return [];
      } else {
        print('获取排行榜失败: HTTP ${response.statusCode}');
        print('响应内容: ${response.body}');
        return []; // 返回空数组而不是抛出异常
      }
    } catch (e) {
      print('获取排行榜失败: $e');
      return []; // 返回空数组而不是抛出异常
    }
  }

  Future<void> updateTransferData(int bytes) async {
    try {
      final response = await HttpService.post(
        AppConfig.updateTransferDataUrl,
        body: {'bytes': bytes},
        useAuth: true,
      );

      if (response.statusCode != 200) {
        throw Exception('更新传输数据失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('更新传输数据失败: $e');
    }
  }
}
