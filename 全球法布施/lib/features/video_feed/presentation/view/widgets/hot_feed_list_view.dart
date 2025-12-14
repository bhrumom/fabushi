import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:preload_page_view/preload_page_view.dart' hide PageScrollPhysics;
import 'package:video_player/video_player.dart';
import '../../../../../services/feed_service.dart';
import '../../../../../services/like_service.dart';
import '../../../../../models/liked_item.dart';
import '../../../../../features/video_feed/domain/entities/video_entity.dart';
import '../../../../../features/video_feed/presentation/view/widgets/video_feed_view_item.dart';

/// 热门内容列表（只显示有点赞量的内容，使用法流样式展示）
class HotFeedListView extends StatefulWidget {
  const HotFeedListView({super.key});

  @override
  State<HotFeedListView> createState() => _HotFeedListViewState();
}

class _HotFeedListViewState extends State<HotFeedListView> {
  final LikeService _likeService = LikeService();
  
  List<VideoEntity> _hotVideos = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final PreloadPageController _pageController = PreloadPageController();
  
  // Video controller cache
  final Map<String, VideoPlayerController> _controllerCache = {};
  final List<String> _accessOrder = [];
  final int _maxCacheSize = 3;

  @override
  void initState() {
    super.initState();
    _likeService.initialize();
    _loadHotContent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  Future<void> _disposeAllControllers() async {
    for (final controller in _controllerCache.values) {
      try {
        if (controller.value.isInitialized) {
          await controller.pause();
        }
        await controller.dispose();
      } catch (e) {
        debugPrint('Error disposing controller: $e');
      }
    }
    _controllerCache.clear();
    _accessOrder.clear();
  }

  Future<void> _loadHotContent() async {
    setState(() => _isLoading = true);

    try {
      // 获取已点赞的内容列表
      final likedItems = _likeService.getLikedItems();
      
      if (likedItems.isEmpty) {
        if (mounted) {
          setState(() {
            _hotVideos = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 先获取点赞数
      final contentIds = likedItems.map((item) => item.id).toList();
      await _likeService.fetchLikeCounts(contentIds);

      // 将 LikedItem 转换为 VideoEntity
      final videos = likedItems.map((item) {
        // 获取点赞数，至少显示1（因为用户已经点赞了）
        int likeCount = _likeService.getLikeCount(item.id);
        if (likeCount == 0) likeCount = 1;
        
        return VideoEntity(
          id: item.id,
          username: item.username,
          description: item.description,
          videoUrl: item.videoUrl ?? '',
          profileImageUrl: item.profileImageUrl,
          likeCount: likeCount,
          commentCount: 0,
          shareCount: 0,
          timestamp: item.likedAt,
          contentType: item.contentType == 'video' ? ContentType.video : ContentType.text,
          textContent: item.textContent,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _hotVideos = videos;
          _isLoading = false;
        });

        // 初始化第一个视频
        if (_hotVideos.isNotEmpty && _hotVideos[0].contentType == ContentType.video) {
          await _initAndPlayVideo(0);
        }
      }
    } catch (e) {
      debugPrint('加载热门内容失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initAndPlayVideo(int index) async {
    if (_hotVideos.isEmpty || index >= _hotVideos.length) return;
    
    final video = _hotVideos[index];
    if (video.contentType != ContentType.video || video.videoUrl.isEmpty) return;
    
    await _getOrCreateController(video);
    await _playController(video.id);
    if (mounted) setState(() {});
  }

  Future<VideoPlayerController?> _getOrCreateController(VideoEntity video) async {
    if (video.contentType == ContentType.text || video.videoUrl.isEmpty) {
      return null;
    }

    if (_controllerCache.containsKey(video.id)) {
      _touchController(video.id);
      return _controllerCache[video.id];
    }

    try {
      final cacheManager = DefaultCacheManager();
      final file = await cacheManager.getSingleFile(video.videoUrl);
      
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(true);
      
      _controllerCache[video.id] = controller;
      _touchController(video.id);
      _enforceCacheLimit();
      
      return controller;
    } catch (e) {
      debugPrint('Error initializing controller: $e');
      return null;
    }
  }

  void _touchController(String videoId) {
    _accessOrder.remove(videoId);
    _accessOrder.add(videoId);
  }

  void _enforceCacheLimit() {
    while (_controllerCache.length > _maxCacheSize && _accessOrder.isNotEmpty) {
      final oldestId = _accessOrder.first;
      _removeController(oldestId);
    }
  }

  Future<void> _removeController(String videoId) async {
    final controller = _controllerCache.remove(videoId);
    _accessOrder.remove(videoId);
    if (controller != null) {
      try {
        if (controller.value.isInitialized) await controller.pause();
        await controller.dispose();
      } catch (e) {
        debugPrint('Error disposing controller: $e');
      }
    }
  }

  Future<void> _playController(String videoId) async {
    final controller = _controllerCache[videoId];
    if (controller != null && controller.value.isInitialized && !controller.value.isPlaying) {
      try {
        await controller.play();
      } catch (e) {
        debugPrint('Error playing video: $e');
      }
    }
  }

  Future<void> _pauseAllControllers() async {
    for (final controller in _controllerCache.values) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          await controller.pause();
        }
      } catch (e) {
        debugPrint('Error pausing video: $e');
      }
    }
  }

  Future<void> _handlePageChange(int newPage) async {
    _currentPage = newPage;
    await _pauseAllControllers();
    await _initAndPlayVideo(newPage);
  }

  VideoPlayerController? _getController(String videoId) {
    return _controllerCache[videoId];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_hotVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('暂无热门内容', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('在法流页面点赞的内容会出现在这里', style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHotContent,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return PreloadPageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _hotVideos.length,
      physics: const BouncingScrollPhysics(),
      onPageChanged: _handlePageChange,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: VideoFeedViewItem(
            key: ValueKey(_hotVideos[index].id),
            controller: _getController(_hotVideos[index].id),
            videoItem: _hotVideos[index],
          ),
        );
      },
    );
  }
}
