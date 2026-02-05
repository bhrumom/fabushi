import 'package:flutter/foundation.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';

/// 视频标题映射服务 - 用于在感应/发愿分区显示原视频标题
class VideoTitleService {
  static final VideoTitleService _instance = VideoTitleService._internal();
  factory VideoTitleService() => _instance;
  VideoTitleService._internal();

  // 存储视频ID到完整视频数据的映射
  final Map<String, VideoEntity> _videoCache = {};
  
  /// 注册视频到缓存（在VideoFeedView加载时调用）
  void registerVideos(List<VideoEntity> videos) {
    for (final video in videos) {
      // 用 id 作为 key 注册
      _videoCache[video.id] = video;
      // 同时用 filePath 作为 key 注册（如果有的话）
      if (video.filePath != null && video.filePath!.isNotEmpty) {
        _videoCache[video.filePath!] = video;
      }
    }
    debugPrint('VideoTitleService: 注册了 ${videos.length} 个视频，缓存大小: ${_videoCache.length}');
  }
  
  /// 根据视频ID获取标题
  String? getVideoTitle(String videoId) {
    final video = _videoCache[videoId];
    return video?.username; // username 字段存储的是标题
  }
  
  /// 根据视频ID获取完整视频数据
  VideoEntity? getVideo(String videoId) {
    return _videoCache[videoId];
  }
  
  /// 根据标题搜索视频（用于旧评论数据的兼容）
  VideoEntity? getVideoByTitle(String title) {
    try {
      return _videoCache.values.firstWhere(
        (video) => video.username == title,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// 获取所有已缓存视频的ID列表
  List<String> get cachedVideoIds => _videoCache.keys.toList();
  
  /// 获取所有已缓存的视频实体列表
  List<VideoEntity> getAllVideos() => _videoCache.values.toList();
  
  /// 清空缓存
  void clear() {
    _videoCache.clear();
  }
}
