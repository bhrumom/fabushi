import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/comment_model.dart';
import 'http_service.dart';
import 'meditation_session_manager.dart';

typedef MainPracticeProvider = String? Function();

abstract class CommentHttpClient {
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

  Future<http.Response> delete(
    String url, {
    bool useAuth = false,
  });
}

class DefaultCommentHttpClient implements CommentHttpClient {
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

  @override
  Future<http.Response> delete(
    String url, {
    bool useAuth = false,
  }) {
    return HttpService.delete(url, useAuth: useAuth);
  }
}

/// 评论服务 - 管理内容评论
///
/// 使用统一的 contentId 标识内容（替代原来的 videoId）
class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;

  CommentService._internal()
    : _httpClient = DefaultCommentHttpClient(),
      _mainPracticeProvider = _defaultMainPracticeProvider;

  CommentService.withDependencies({
    required CommentHttpClient httpClient,
    MainPracticeProvider? mainPracticeProvider,
  }) : _httpClient = httpClient,
       _mainPracticeProvider =
           mainPracticeProvider ?? _defaultMainPracticeProvider;

  final CommentHttpClient _httpClient;
  final MainPracticeProvider _mainPracticeProvider;

  static String? _defaultMainPracticeProvider() {
    return MeditationSessionManager().lockedPractice?.title;
  }

  // 评论数缓存（使用 contentId 作为 key）
  final Map<String, int> _commentCounts = {};

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

  String? _extractErrorKey(Map<String, dynamic>? data) {
    final errorKey = data?['errorKey'] ?? data?['code'];
    if (errorKey is String && errorKey.isNotEmpty) {
      return errorKey;
    }
    return null;
  }

  Map<String, dynamic> _buildFailurePayload(
    http.Response response, {
    String fallbackError = '操作失败',
  }) {
    final data = _tryParseBodyAsMap(response);
    final payload = <String, dynamic>{
      'success': false,
      'error': HttpService.getErrorMessage(response),
      'statusCode': response.statusCode,
    };

    final errorKey = _extractErrorKey(data);
    if (errorKey != null) {
      payload['errorKey'] = errorKey;
    }

    if ((payload['error'] as String).trim().isEmpty) {
      payload['error'] = fallbackError;
    }

    return payload;
  }

  List<CommentModel> _parseComments(List<dynamic> commentsJson) {
    final comments = <CommentModel>[];

    for (final item in commentsJson) {
      if (item is! Map) {
        continue;
      }

      try {
        comments.add(CommentModel.fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        debugPrint('跳过格式错误的评论数据: $e');
      }
    }

    return comments;
  }

  // 获取缓存的评论数
  int getCommentCount(String contentId) => _commentCounts[contentId] ?? 0;

  // 批量获取评论数（使用 contentId）
  Future<void> fetchCommentCounts(List<String> contentIds) async {
    if (contentIds.isEmpty) return;

    try {
      final response = await _httpClient.post(
        '${AppConfig.apiUrl}/api/comments/batch-counts',
        body: {'videoIds': contentIds}, // 后端兼容 videoIds 参数名
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = _tryParseBodyAsMap(response);
      final counts = data?['counts'];
      if (counts is! Map) {
        return;
      }

      for (final entry in counts.entries) {
        final value = entry.value;
        if (value is num) {
          _commentCounts[entry.key.toString()] = value.toInt();
        }
      }
      debugPrint('获取评论数成功: ${counts.length} 个');
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
      final response = await _httpClient.get(
        '${AppConfig.apiUrl}/api/comments?contentId=$contentId&page=$page&pageSize=$pageSize',
      );

      if (response.statusCode != 200) {
        debugPrint('获取评论失败: ${response.statusCode}');
        return [];
      }

      final data = _tryParseBodyAsMap(response);
      final commentsJson = data?['comments'];
      if (commentsJson is List) {
        return _parseComments(commentsJson);
      }

      return [];
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
      };
      if (parentId != null) {
        body['parentId'] = parentId;
      }
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
      final mainPractice = _mainPracticeProvider();
      if (mainPractice != null && mainPractice.isNotEmpty) {
        body['mainPractice'] = mainPractice;
      }

      final response = await _httpClient.post(
        '${AppConfig.apiUrl}/api/comments',
        body: body,
        useAuth: true,
      );

      final data = _tryParseBodyAsMap(response);
      if (response.statusCode == 201 && data != null) {
        final comment = data['comment'];
        if (comment is Map) {
          return {
            'success': true,
            'comment': CommentModel.fromJson(Map<String, dynamic>.from(comment)),
          };
        }
      }

      if (data != null) {
        return _buildFailurePayload(response, fallbackError: '发布失败');
      }

      return {
        'success': false,
        'error': '服务器响应格式错误',
        'statusCode': response.statusCode,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ 发布评论异常: $e');
      debugPrint('❌ 堆栈: $stackTrace');
      return {'success': false, 'error': '发布评论失败：$e'};
    }
  }

  // 删除评论
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await _httpClient.delete(
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
