import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../models/comment_model.dart';
import 'http_service.dart';

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  // 评论数缓存
  final Map<String, int> _commentCounts = {};

  // 获取缓存的评论数
  int getCommentCount(String videoId) => _commentCounts[videoId] ?? 0;

  // 批量获取评论数
  Future<void> fetchCommentCounts(List<String> videoIds) async {
    if (videoIds.isEmpty) return;
    
    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/comments/batch-counts',
        body: {'videoIds': videoIds},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<String, dynamic> counts = data['counts'];
        for (final entry in counts.entries) {
          _commentCounts[entry.key] = entry.value as int;
        }
        debugPrint('获取评论数成功: ${counts.length} 个');
      }
    } catch (e) {
      debugPrint('批量获取评论数异常: $e');
    }
  }

  // 获取评论列表
  Future<List<CommentModel>> getComments(String videoId, {int page = 1, int pageSize = 20}) async {
    try {
      final response = await HttpService.get(
        '${AppConfig.apiUrl}/api/comments?videoId=$videoId&page=$page&pageSize=$pageSize',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> commentsJson = data['comments'];
        return commentsJson.map((json) => CommentModel.fromJson(json)).toList();
      } else {
        debugPrint('获取评论失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('获取评论异常: $e');
      return [];
    }
  }

  // 发布评论（支持标签：ganying/fayuan，支持视频标题和文件路径）
  Future<Map<String, dynamic>> postComment(String videoId, String content, {int? parentId, String? tag, String? videoTitle, String? filePath}) async {
    try {
      final body = <String, dynamic>{
        'videoId': videoId,
        'content': content,
        'parentId': parentId,
      };
      if (tag != null) {
        body['tag'] = tag;
      }
      if (videoTitle != null) {
        body['videoTitle'] = videoTitle;
      }
      if (filePath != null) {
        body['filePath'] = filePath;
      }
      
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/comments',
        body: body,
        useAuth: true,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'comment': CommentModel.fromJson(data['comment'])};
      } else {
        debugPrint('发布评论失败: ${response.statusCode} ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'error': errorData['error'] ?? '发布失败'};
        } catch (_) {
          return {'success': false, 'error': '发布失败: ${response.statusCode}'};
        }
      }
    } catch (e) {
      debugPrint('发布评论异常: $e');
      return {'success': false, 'error': '网络错误，请检查网络连接'};
    }
  }

  // 删除评论
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await HttpService.delete(
        '${AppConfig.apiUrl}/api/comments?id=$commentId',
        useAuth: true,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('删除评论异常: $e');
      return false;
    }
  }
}
