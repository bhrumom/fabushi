import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../models/comment_model.dart';
import 'http_service.dart';

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

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

  // 发布评论（支持标签：ganying/fayuan）
  Future<Map<String, dynamic>> postComment(String videoId, String content, {int? parentId, String? tag}) async {
    try {
      final body = <String, dynamic>{
        'videoId': videoId,
        'content': content,
        'parentId': parentId,
      };
      if (tag != null) {
        body['tag'] = tag;
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
