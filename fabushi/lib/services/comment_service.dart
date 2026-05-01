import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../models/comment_model.dart';
import 'http_service.dart';
import 'meditation_session_manager.dart';

/// 评论服务 - 管理内容评论
///
/// 使用统一的 contentId 标识内容（替代原来的 videoId）

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  // 评论数缓存（使用 contentId 作为 key）
  final Map<String, int> _commentCounts = {};

  // 获取缓存的评论数
  int getCommentCount(String contentId) => _commentCounts[contentId] ?? 0;

  // 批量获取评论数（使用 contentId）
  Future<void> fetchCommentCounts(List<String> contentIds) async {
    if (contentIds.isEmpty) return;

    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/comments/batch-counts',
        body: {'videoIds': contentIds}, // 后端兼容 videoIds 参数名
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

  // 获取评论列表（使用 contentId）
  Future<List<CommentModel>> getComments(
    String contentId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await HttpService.get(
        '${AppConfig.apiUrl}/api/comments?contentId=$contentId&page=$page&pageSize=$pageSize',
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

  // 发布评论（支持标签：ganying/fayuan，支持内容标题和文件路径）
  /// [contentId] 统一内容标识符
  /// [content] 评论内容
  /// [parentId] 父评论ID（回复时使用）
  /// [tag] 标签（ganying/fayuan）
  /// [contentTitle] 关联内容的标题
  /// [filePath] 文件路径
  Future<Map<String, dynamic>> postComment(
    String contentId,
    String content, {
    int? parentId,
    String? tag,
    String? contentTitle,
    String? filePath,
    String? attachmentPath,
    String? attachmentType,
  }) async {
    // 前端验证：确保 contentId 和 content 不为空
    if (contentId.isEmpty) {
      debugPrint('❌ 发布评论失败: contentId 为空');
      return {'success': false, 'error': '内容ID不能为空，请刷新页面重试'};
    }
    if (content.trim().isEmpty) {
      debugPrint('❌ 发布评论失败: content 为空');
      return {'success': false, 'error': '评论内容不能为空'};
    }

    debugPrint(
      '📝 发布评论: contentId=$contentId, content长度=${content.length}, tag=$tag, filePath=$filePath',
    );

    try {
      final body = <String, dynamic>{
        'contentId': contentId,
        'content': content,
        'parentId': parentId,
      };
      if (tag != null) {
        body['tag'] = tag;
      }
      if (contentTitle != null) {
        body['videoTitle'] = contentTitle; // 后端兼容 videoTitle 参数名
      }
      if (filePath != null) {
        body['filePath'] = filePath;
      }
      if (attachmentPath != null) {
        body['attachment_path'] = attachmentPath;
      }
      if (attachmentType != null) {
        body['attachment_type'] = attachmentType;
      }

      // 自动附带当前用户的主修功课
      final mainPractice = MeditationSessionManager().lockedPractice?.title;
      if (mainPractice != null) {
        body['mainPractice'] = mainPractice;
      }

      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/comments',
        body: body,
        useAuth: true,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'comment': CommentModel.fromJson(data['comment']),
        };
      } else {
        debugPrint('发布评论失败: ${response.statusCode} ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'error': errorData['error'] ?? '发布失败'};
        } catch (_) {
          return {'success': false, 'error': '发布失败: ${response.statusCode}'};
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 发布评论异常: $e');
      debugPrint('❌ 堆栈: $stackTrace');
      return {'success': false, 'error': '发布评论失败：$e'};
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
