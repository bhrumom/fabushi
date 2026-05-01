import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../models/feed_post_model.dart';
import 'http_service.dart';

/// 帖子/动态服务（感应/发愿列表、热门内容）
class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  /// 获取带标签的帖子列表（感应/发愿）
  Future<List<FeedPostModel>> getTaggedPosts(
    String tag, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await HttpService.get(
        '${AppConfig.apiUrl}/api/posts?tag=$tag&page=$page&pageSize=$pageSize',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> postsJson = data['posts'] ?? [];
        return postsJson.map((json) => FeedPostModel.fromJson(json)).toList();
      } else {
        debugPrint('获取帖子列表失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('获取帖子列表异常: $e');
      return [];
    }
  }

  /// 获取感应列表
  Future<List<FeedPostModel>> getGanyingPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    return getTaggedPosts('ganying', page: page, pageSize: pageSize);
  }

  /// 获取发愿列表
  Future<List<FeedPostModel>> getFayuanPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    return getTaggedPosts('fayuan', page: page, pageSize: pageSize);
  }

  /// 获取帖子详情
  Future<FeedPostModel?> getPostDetail(int postId) async {
    try {
      final response = await HttpService.get(
        '${AppConfig.apiUrl}/api/posts/detail?id=$postId',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FeedPostModel.fromJson(data['post']);
      } else {
        debugPrint('获取帖子详情失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('获取帖子详情异常: $e');
      return null;
    }
  }

  /// 获取热门内容（按点赞数排序）
  Future<List<Map<String, dynamic>>> getHotFeed({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await HttpService.get(
        '${AppConfig.apiUrl}/api/feed/hot?page=$page&pageSize=$pageSize',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> hotContent = data['hotContent'] ?? [];
        return hotContent
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } else {
        debugPrint('获取热门内容失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('获取热门内容异常: $e');
      return [];
    }
  }
}
