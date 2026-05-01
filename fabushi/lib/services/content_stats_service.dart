import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import 'http_service.dart';

/// 统一的内容统计服务（点赞数+评论数）
/// 减少API请求次数，一次获取所有统计数据
class ContentStatsService {
  static final ContentStatsService _instance = ContentStatsService._internal();
  factory ContentStatsService() => _instance;
  ContentStatsService._internal();

  // 点赞数缓存
  final Map<String, int> _likeCounts = {};

  // 评论数缓存
  final Map<String, int> _commentCounts = {};

  // 获取缓存的点赞数
  int getLikeCount(String contentId) => _likeCounts[contentId] ?? 0;

  // 获取缓存的评论数
  int getCommentCount(String contentId) => _commentCounts[contentId] ?? 0;

  // 更新本地点赞数（用于即时反馈）
  void updateLikeCount(String contentId, int count) {
    _likeCounts[contentId] = count;
  }

  // 更新本地评论数（用于即时反馈）
  void updateCommentCount(String contentId, int count) {
    _commentCounts[contentId] = count;
  }

  // 增加评论数（发表评论后调用）
  void incrementCommentCount(String contentId) {
    _commentCounts[contentId] = (_commentCounts[contentId] ?? 0) + 1;
  }

  /// 批量获取内容统计（点赞数+评论数）- 单次请求
  Future<void> fetchContentStats(List<String> contentIds) async {
    if (contentIds.isEmpty) return;

    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/content/batch-stats',
        body: {'contentIds': contentIds},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<String, dynamic> stats = data['stats'];

        for (final entry in stats.entries) {
          final contentId = entry.key;
          final statData = entry.value as Map<String, dynamic>;
          _likeCounts[contentId] = statData['likeCount'] as int? ?? 0;
          _commentCounts[contentId] = statData['commentCount'] as int? ?? 0;
        }

        debugPrint('ContentStatsService: 获取 ${stats.length} 个内容的统计数据');
      }
    } catch (e) {
      debugPrint('获取内容统计异常: $e');
    }
  }

  // 清空缓存
  void clear() {
    _likeCounts.clear();
    _commentCounts.clear();
  }
}
