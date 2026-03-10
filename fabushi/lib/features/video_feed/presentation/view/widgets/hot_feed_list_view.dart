import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:preload_page_view/preload_page_view.dart' hide PageScrollPhysics;
import 'package:video_player/video_player.dart';
import '../../../../../services/content_filter_service.dart';
import '../../../../../services/feed_service.dart';
import '../../../../../services/cloudflare_text_service.dart';
import '../../../../../services/user_block_service.dart';
import '../../../../../features/video_feed/domain/entities/video_entity.dart';
import '../../../../../features/video_feed/presentation/view/widgets/video_feed_view_item.dart';

/// 热门内容列表（从后端获取热门内容，根据 file_path 加载完整内容）
class HotFeedListView extends StatefulWidget {
  const HotFeedListView({
    super.key,
    this.isTabActive = true,
  });
  
  /// 当前 tab 是否激活（用于控制 TTS 播放）
  final bool isTabActive;

  @override
  State<HotFeedListView> createState() => _HotFeedListViewState();
}

class _HotFeedListViewState extends State<HotFeedListView>
    with AutomaticKeepAliveClientMixin {
  final FeedService _feedService = FeedService();
  final CloudflareTextService _textService = CloudflareTextService();
  
  List<VideoEntity> _hotVideos = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final PreloadPageController _pageController = PreloadPageController();
  bool _hasLoadedOnce = false;
  
  // Video controller cache
  final Map<String, VideoPlayerController> _controllerCache = {};
  final List<String> _accessOrder = [];
  final int _maxCacheSize = 3;

  @override
  bool get wantKeepAlive => true;

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
      // 1. 从后端API获取热门内容列表（包含 title 和 file_path）
      final hotContentList = await _feedService.getHotFeed(page: 1, pageSize: 50);
      
      debugPrint('获取到 ${hotContentList.length} 条热门内容');

      // 🔥 过滤：只保留有点赞或评论的内容
      final filteredContentList = hotContentList.where((item) {
        final likeCount = item['like_count'] as int? ?? 0;
        final commentCount = item['comment_count'] as int? ?? 0;
        return likeCount > 0 || commentCount > 0;
      }).toList();
      
      debugPrint('🔥 过滤后剩余 ${filteredContentList.length} 条有互动的内容');

      if (filteredContentList.isEmpty) {
        if (mounted) {
          setState(() {
            _hotVideos = [];
            _isLoading = false;
            _hasLoadedOnce = true;
          });
        }
        return;
      }

      // 🚀 渐进加载：加载一个显示一个，不等待全部完成
      _hasLoadedOnce = true;
      
      // 🚀 渐进加载：使用 Future.wait 并行处理内容，提高加载速度
      _hasLoadedOnce = true;
      
      // 平行处理所有热门内容
      final videoFutures = filteredContentList.map((hotItem) async {
        final contentId = hotItem['id'] as String;
        final contentType = hotItem['content_type'] as String? ?? 'text';
        final title = hotItem['title'] as String?;
        final filePath = hotItem['file_path'] as String?;
        final likeCount = hotItem['like_count'] as int? ?? 0;
        final commentCount = hotItem['comment_count'] as int? ?? 0;
        
        debugPrint('🔥 并行处理热门内容: id=$contentId, title=$title');

        if (contentType == 'text') {
          // 文本内容：并行加载，优先本地缓存
          String? textContent;
          String displayTitle = title ?? '热门内容';
          
          if (filePath != null && filePath.isNotEmpty) {
            textContent = await _loadTextFromFilePath(filePath);
          }
          
          if (textContent == null) {
            final randomContent = await _textService.getRandomTextContent();
            if (randomContent != null) {
              textContent = randomContent['content'];
              displayTitle = randomContent['title'] ?? displayTitle;
            }
          }
          
          if (textContent != null) {
            return VideoEntity(
              id: contentId,
              username: displayTitle,
              description: '点击头像阅读全文',
              videoUrl: '',
              profileImageUrl: '',
              likeCount: likeCount,
              commentCount: commentCount,
              shareCount: 0,
              timestamp: DateTime.now(),
              contentType: ContentType.text,
              textContent: textContent,
              filePath: filePath,
            );
          }
        } else {
          // 视频内容
          return VideoEntity(
            id: contentId,
            username: title ?? '热门视频',
            description: '',
            videoUrl: '',
            profileImageUrl: '',
            likeCount: likeCount,
            commentCount: commentCount,
            shareCount: 0,
            timestamp: DateTime.now(),
            contentType: ContentType.video,
          );
        }
        return null;
      }).toList();

      // 等待所有内容加载完成
      final results = await Future.wait(videoFutures);
      var validVideos = results.whereType<VideoEntity>().toList();

      // 🛡️ UGC 安全：过滤被屏蔽用户的内容
      final blockService = UserBlockService();
      validVideos = validVideos.where((v) => !blockService.shouldFilter(v.id)).toList();

      // 🛡️ UGC 安全：过滤含不当内容的文本
      validVideos = ContentFilterService.filterVideos(validVideos);

      debugPrint('🛡️ 安全过滤后: ${validVideos.length} 条热门内容');

      if (mounted) {
        setState(() {
          _hotVideos = validVideos;
          _isLoading = false;
        });
        
        // 如果第一条是视频，初始化它
        if (_hotVideos.isNotEmpty && _hotVideos[0].contentType == ContentType.video) {
          _initAndPlayVideo(0);
        }
      }
      
      debugPrint('🔥 热门内容加载完成，共 ${_hotVideos.length} 条');
      
    } catch (e) {
      debugPrint('加载热门内容失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  /// 根据 filePath 加载文本内容（复用 CloudflareTextService 逻辑）
  Future<String?> _loadTextFromFilePath(String filePath) async {
    try {
      debugPrint('尝试从 filePath 加载: $filePath');
      if (filePath.isEmpty) return null;
      
      final result = await _textService.getTextByFilePath(filePath);
      if (result != null) {
        return result['content'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('加载文本失败: $e');
      return null;
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
    debugPrint('🔊 热门页面切换: $_currentPage -> $newPage');
    setState(() {
      _currentPage = newPage; // 触发rebuild，更新isVisible
    });
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
      return RefreshIndicator(
        onRefresh: _refreshHotContent,
        color: Colors.white,
        backgroundColor: Colors.white24,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Center(
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
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 检测是否在最后一页并且过度滚动（上拉到底）
        if (notification is OverscrollNotification) {
          // 正值表示向下过度滚动（在底部继续上拉）
          if (notification.overscroll > 0 && 
              _currentPage == _hotVideos.length - 1 &&
              !_isLoading) {
            // 触发刷新
            _refreshHotContent();
          }
        }
        return false;
      },
      child: PreloadPageView.builder(
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
              isVisible: widget.isTabActive && index == _currentPage, // 🔊 TTS只对当前页面且tab激活时播放
            ),
          );
        },
      ),
    );
  }
}
