import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_more_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/bloc/video_feed_state.dart';

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
  final _preloadedFiles = <String, File>{};
  bool _isPreloadingMore = false;

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
        final updatedVideos = [...state.videos, ...moreVideos];
        emit(
          state.copyWith(
            videos: updatedVideos,
            isPaginating: false,
            hasMoreVideos: true,
            errorMessage: '',
          ),
        );
        preloadNextVideos();
      },
    );
  }

  Future<void> onPageChanged(int newIndex) async {
    debugPrint('页面变化: $newIndex / ${state.videos.length}');
    emit(state.copyWith(currentIndex: newIndex));

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
        await _preloadVideo(videoUrl);
      }
    }
  }

  Future<void> _preloadVideo(String videoUrl) async {
    try {
      final file = await getCachedVideoFile(videoUrl);
      _preloadedFiles[videoUrl] = file;

      final currentPreloaded = Set<String>.from(state.preloadedVideoUrls)..add(videoUrl);
      emit(state.copyWith(preloadedVideoUrls: currentPreloaded));
    } catch (e) {
      debugPrint('Error preloading video: $e');
    } finally {
      _preloadQueue.remove(videoUrl);
    }
  }

  Future<File> getCachedVideoFile(String videoUrl) async {
    if (_preloadedFiles.containsKey(videoUrl)) {
      return _preloadedFiles[videoUrl]!;
    }

    final cacheManager = DefaultCacheManager();
    final fileInfo = await cacheManager.getFileFromCache(videoUrl);
    final file = fileInfo?.file ?? await cacheManager.getSingleFile(videoUrl);
    _preloadedFiles[videoUrl] = file;
    return file;
  }

  @override
  Future<void> close() {
    _preloadQueue.clear();
    _preloadedFiles.clear();
    return super.close();
  }
}
