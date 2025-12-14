import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:preload_page_view/preload_page_view.dart' hide PageScrollPhysics;
import 'package:video_player/video_player.dart';
import '../../../../../services/feed_service.dart';
import '../../../../../services/like_service.dart';
import '../../../../../services/content_stats_service.dart';
import '../../../../../services/video_title_service.dart';
import '../../../../../features/video_feed/domain/entities/video_entity.dart';
import '../../../../../features/video_feed/presentation/view/widgets/video_feed_view_item.dart';

/// 热门内容列表（从后端获取全局热门内容，按点赞数排序）
class HotFeedListView extends StatefulWidget {
  const HotFeedListView({super.key});

  @override
  State<HotFeedListView> createState() => _HotFeedListViewState();
}

class _HotFeedListViewState extends State<HotFeedListView>
    with AutomaticKeepAliveClientMixin {
  final FeedService _feedService = FeedService();
  final VideoTitleService _videoTitleService = VideoTitleService();
  
  List<VideoEntity> _hotVideos = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final PreloadPageController _pageController = PreloadPageController();
  bool _hasLoadedOnce = false; // 保持状态标记
  
  // Video controller cache
  final Map<String, VideoPlayerController> _controllerCache = {};
  final List<String> _accessOrder = [];
  final int _maxCacheSize = 3;

  @override
  bool get wantKeepAlive => true; // 保持状态

  @override
  void initState() {
    super.initState();
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
    // 如果已经加载过且有数据，不重复加载
    if (_hasLoadedOnce && _hotVideos.isNotEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      // 从后端API获取全局热门内容
      final hotContentList = await _feedService.getHotFeed(page: 1, pageSize: 50);
      
      if (hotContentList.isEmpty) {
        if (mounted) {
          setState(() {
            _hotVideos = [];
            _isLoading = false;
            _hasLoadedOnce = true;
          });
        }
        return;
      }

      debugPrint('获取到 ${hotContentList.length} 条热门内容');

      // 获取详细的内容信息
      final List<VideoEntity> videos = [];
      
      for (final hotItem in hotContentList) {
        final contentId = hotItem['id'] as String;
        final contentType = hotItem['content_type'] as String? ?? 'text';
        final likeCount = hotItem['like_count'] as int? ?? 0;
        
        // 尝试从 VideoTitleService 获取已加载的视频信息
        final existingVideo = _videoTitleService.getVideo(contentId);
        
        if (existingVideo != null) {
          // 使用已有的视频信息，但更新点赞数
          videos.add(VideoEntity(
            id: existingVideo.id,
            username: existingVideo.username,
            description: existingVideo.description,
            videoUrl: existingVideo.videoUrl,
            profileImageUrl: existingVideo.profileImageUrl,
            likeCount: likeCount,
            commentCount: existingVideo.commentCount,
            shareCount: existingVideo.shareCount,
            timestamp: existingVideo.timestamp,
            contentType: existingVideo.contentType,
            textContent: existingVideo.textContent,
          ));
        } else {
          // 如果没有缓存的视频信息，创建一个基本的实体
          // 这种情况可能是用户还没有浏览过法流页面
          videos.add(VideoEntity(
            id: contentId,
            username: '',
            description: '热门内容',
            videoUrl: '',
            profileImageUrl: '',
            likeCount: likeCount,
            commentCount: 0,
            shareCount: 0,
            timestamp: DateTime.now(),
            contentType: contentType == 'video' ? ContentType.video : ContentType.text,
            textContent: contentType == 'text' ? '加载中...' : null,
          ));
        }
      }

      // 获取点赞数和评论数（单次API请求）
      if (videos.isNotEmpty) {
        final contentIds = videos.map((v) => v.id).toList();
        await ContentStatsService().fetchContentStats(contentIds);
        
        // 更新统计信息
        for (int i = 0; i < videos.length; i++) {
          final v = videos[i];
          final updatedLikeCount = ContentStatsService().getLikeCount(v.id);
          final updatedCommentCount = ContentStatsService().getCommentCount(v.id);
          
          if (updatedLikeCount > 0 || updatedCommentCount > 0) {
            videos[i] = VideoEntity(
              id: v.id,
              username: v.username,
              description: v.description,
              videoUrl: v.videoUrl,
              profileImageUrl: v.profileImageUrl,
              likeCount: updatedLikeCount > 0 ? updatedLikeCount : v.likeCount,
              commentCount: updatedCommentCount > 0 ? updatedCommentCount : v.commentCount,
              shareCount: v.shareCount,
              timestamp: v.timestamp,
              contentType: v.contentType,
              textContent: v.textContent,
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _hotVideos = videos;
          _isLoading = false;
          _hasLoadedOnce = true;
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

  /// 强制刷新热门内容
  Future<void> _refreshHotContent() async {
    _hasLoadedOnce = false;
    await _loadHotContent();
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
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
            const Icon(Icons.local_fire_department_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('暂无热门内容', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('快去法流页面点赞喜欢的内容吧~', style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshHotContent,
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
