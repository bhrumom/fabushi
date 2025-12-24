import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_more_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/bloc/video_feed_state.dart';

/// 第一性原理内存优化：
/// 1. 视频文件引用缓存使用 LRU 策略，限制最大数量
/// 2. 文件本身由 DefaultCacheManager 管理磁盘缓存
/// 3. 内存中只保留最近访问的 N 个文件引用
class VideoFeedCubit extends Cubit<VideoFeedState> {
  VideoFeedCubit({
    required FetchVideosUseCase fetchVideosUseCase,
    required FetchMoreVideosUseCase fetchMoreVideosUseCase,
  }) : _fetchVideosUseCase = fetchVideosUseCase,
       _fetchMoreVideosUseCase = fetchMoreVideosUseCase,
       super(VideoFeedState.initial()) {
    loadVideos();
  }

  final FetchVideosUseCase _fetchVideosUseCase;
  final FetchMoreVideosUseCase _fetchMoreVideosUseCase;
  final _preloadQueue = Queue<String>();
  
  /// 🚀 第一性原理优化：LRU 缓存限制
  /// 使用 LinkedHashMap 保持插入顺序，便于 LRU 淘汰
  /// 最大缓存 8 个视频文件引用（约 100-200MB 内存占用）
  static const int _maxCacheSize = 8;
  final LinkedHashMap<String, File> _preloadedFiles = LinkedHashMap<String, File>();
  
  bool _isPreloadingMore = false;

  /// 🔄 LRU 缓存访问：移到末尾表示最近使用
  void _touchCache(String url, File file) {
    _preloadedFiles.remove(url);
    _preloadedFiles[url] = file;
  }

  /// 🧹 强制执行缓存大小限制
  void _enforceCacheLimit() {
    while (_preloadedFiles.length > _maxCacheSize) {
      final oldestKey = _preloadedFiles.keys.first;
      _preloadedFiles.remove(oldestKey);
      debugPrint('📊 内存优化: 淘汰缓存 $oldestKey, 当前缓存数: ${_preloadedFiles.length}');
    }
  }

  Future<void> loadVideos() async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));

    final result = await _fetchVideosUseCase();

    result.fold(
      (error) {
        emit(state.copyWith(isLoading: false, isSuccess: false, errorMessage: error));
      },
      (videos) {
        // 总是有更多内容（文本可以无限加载）
        emit(
          state.copyWith(
            isLoading: false,
            isSuccess: true,
            videos: videos,
            hasMoreVideos: true,
            currentIndex: 0,
            errorMessage: '',
          ),
        );

        // Start preloading next videos after initial load
        if (videos.isNotEmpty) {
          preloadNextVideos();
        }
      },
    );
  }

  Future<void> loadMoreVideos() async {
    if (state.isPaginating || !state.hasMoreVideos) {
      debugPrint('跳过加载: isPaginating=${state.isPaginating}, hasMoreVideos=${state.hasMoreVideos}');
      return;
    }

    debugPrint('开始加载更多内容...');
    emit(state.copyWith(isPaginating: true, errorMessage: ''));

    final result = await _fetchMoreVideosUseCase();

    result.fold(
      (error) {
        debugPrint('加载失败: $error');
        emit(state.copyWith(isPaginating: false, errorMessage: error));
      },
      (moreVideos) {
        debugPrint('加载成功: ${moreVideos.length} 个内容');
        
        // 🚀 24小时优化：视频列表滑动窗口
        // 限制视频列表最大长度，防止无限增长
        var updatedVideos = [...state.videos, ...moreVideos];
        const maxVideoListSize = 50; // 最多保留50个视频实体
        if (updatedVideos.length > maxVideoListSize) {
          // 保留最近的50个
          updatedVideos = updatedVideos.sublist(updatedVideos.length - maxVideoListSize);
          debugPrint('📊 24小时优化: 视频列表裁剪到 $maxVideoListSize 个');
        }
        
        // 🧹 清理 preloadedVideoUrls，只保留窗口内的
        final validUrls = updatedVideos
            .where((v) => v.contentType != ContentType.text)
            .map((v) => v.videoUrl)
            .toSet();
        final cleanedPreloadedUrls = state.preloadedVideoUrls
            .intersection(validUrls);
        
        emit(
          state.copyWith(
            videos: updatedVideos,
            isPaginating: false,
            hasMoreVideos: true,
            errorMessage: '',
            preloadedVideoUrls: cleanedPreloadedUrls,
          ),
        );
        preloadNextVideos();
      },
    );
  }

  Future<void> onPageChanged(int newIndex) async {
    debugPrint('页面变化: $newIndex / ${state.videos.length}');
    emit(state.copyWith(currentIndex: newIndex));

    // 🧹 页面切换时清理远离当前位置的缓存
    _cleanupDistantCache(newIndex);

    await preloadNextVideos();

    // Smart pagination trigger
    if (!_isPreloadingMore && state.hasMoreVideos && newIndex >= state.videos.length - 2) {
      debugPrint('触发分页加载');
      _isPreloadingMore = true;
      try {
        await loadMoreVideos();
      } finally {
        _isPreloadingMore = false;
      }
    }
  }

  /// 🧹 清理距离当前位置超过阈值的缓存
  void _cleanupDistantCache(int currentIndex) {
    if (state.videos.isEmpty) return;
    
    // 获取当前窗口内的视频 URL
    final windowStart = (currentIndex - 2).clamp(0, state.videos.length - 1);
    final windowEnd = (currentIndex + 3).clamp(0, state.videos.length - 1);
    
    final urlsToKeep = <String>{};
    for (int i = windowStart; i <= windowEnd; i++) {
      final video = state.videos[i];
      if (video.contentType != ContentType.text) {
        urlsToKeep.add(video.videoUrl);
      }
    }
    
    // 移除窗口外的缓存
    final urlsToRemove = _preloadedFiles.keys
        .where((url) => !urlsToKeep.contains(url))
        .toList();
    
    for (final url in urlsToRemove) {
      _preloadedFiles.remove(url);
    }
    
    if (urlsToRemove.isNotEmpty) {
      debugPrint('📊 内存优化: 清理 ${urlsToRemove.length} 个远离缓存, 保留 ${_preloadedFiles.length} 个');
    }
  }

  Future<void> preloadNextVideos() async {
    if (state.videos.isEmpty) return;

    final currentIndex = state.currentIndex;
    final videosToPreload = state.videos
        .skip(currentIndex + 1)
        .take(2)
        .where((v) => v.contentType != ContentType.text) // Skip text content
        .map((v) => v.videoUrl)
        .where((url) => url.isNotEmpty && !_preloadedFiles.containsKey(url));

    for (final videoUrl in videosToPreload) {
      if (!_preloadQueue.contains(videoUrl)) {
        _preloadQueue.add(videoUrl);
        // 关键修复：让出主线程控制权，避免阻塞UI
        await Future.delayed(Duration.zero);
        await _preloadVideo(videoUrl);
      }
    }
  }

  Future<void> _preloadVideo(String videoUrl) async {
    try {
      // 关键修复：让出主线程控制权
      await Future.delayed(Duration.zero);
      
      final file = await getCachedVideoFile(videoUrl);
      _touchCache(videoUrl, file);
      _enforceCacheLimit();

      final currentPreloaded = Set<String>.from(state.preloadedVideoUrls)..add(videoUrl);
      emit(state.copyWith(preloadedVideoUrls: currentPreloaded));
      
      debugPrint('📊 缓存状态: ${_preloadedFiles.length}/$_maxCacheSize');
    } catch (e) {
      debugPrint('Error preloading video: $e');
    } finally {
      _preloadQueue.remove(videoUrl);
    }
  }

  Future<File> getCachedVideoFile(String videoUrl) async {
    // 🚀 LRU: 如果已缓存，更新访问顺序并返回
    if (_preloadedFiles.containsKey(videoUrl)) {
      final file = _preloadedFiles[videoUrl]!;
      _touchCache(videoUrl, file);
      return file;
    }

    // 关键修复：让出主线程控制权
    await Future.delayed(Duration.zero);

    final cacheManager = DefaultCacheManager();
    final fileInfo = await cacheManager.getFileFromCache(videoUrl);
    final file = fileInfo?.file ?? await cacheManager.getSingleFile(videoUrl);
    
    // 添加到 LRU 缓存
    _touchCache(videoUrl, file);
    _enforceCacheLimit();
    
    return file;
  }

  @override
  Future<void> close() {
    debugPrint('📊 VideoFeedCubit 关闭, 清理 ${_preloadedFiles.length} 个缓存');
    _preloadQueue.clear();
    _preloadedFiles.clear();
    return super.close();
  }
}
