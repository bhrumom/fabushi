import 'dart:convert';
import '../config/unified_config.dart';
import 'http_service.dart';

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final response = await HttpService.get(
        UnifiedConfig.leaderboardUrl,
        useAuth: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
      } else {
        throw Exception('获取排行榜失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('获取排行榜失败: $e');
      rethrow;
    }
  }

  Future<void> updateTransferData(int bytes) async {
    try {
      final response = await HttpService.post(
        UnifiedConfig.updateTransferDataUrl,
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
