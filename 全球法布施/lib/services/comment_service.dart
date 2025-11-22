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

  // 发布评论
  Future<CommentModel?> postComment(String videoId, String content, {int? parentId}) async {
    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/comments',
        body: {
          'videoId': videoId,
          'content': content,
          'parentId': parentId,
        },
        useAuth: true,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return CommentModel.fromJson(data['comment']);
      } else {
        debugPrint('发布评论失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('发布评论异常: $e');
      return null;
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
