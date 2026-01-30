// Firebase/Firestore removed for Windows compatibility
import 'package:flutter/foundation.dart';
import 'package:global_dharma_sharing/features/video_feed/data/repository_impl/video_feed_repository_impl.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/repositories/video_feed_repository.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_more_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:global_dharma_sharing/services/cloudflare_text_service.dart';
import 'package:get_it/get_it.dart';

final videoFeedGetIt = GetIt.instance;

void setupVideoFeedDependencies() {
  // Firebase/Firestore removed for Windows compatibility
  debugPrint('🔧 Firebase/Firestore 已移除 (Windows兼容性)');

  // Services - Eager singleton for immediate preloading
  final textService = CloudflareTextService();
  videoFeedGetIt.registerSingleton<CloudflareTextService>(textService);

  // Repositories - no longer uses Firebase
  videoFeedGetIt.registerLazySingleton<VideoFeedRepository>(
    () {
      return VideoFeedRepositoryImpl(
        textService: videoFeedGetIt<CloudflareTextService>(),
      );
    },
  );

  // UseCases
  videoFeedGetIt.registerLazySingleton<FetchVideosUseCase>(
    () => FetchVideosUseCase(repository: videoFeedGetIt<VideoFeedRepository>()),
  );

  videoFeedGetIt.registerLazySingleton<FetchMoreVideosUseCase>(
    () => FetchMoreVideosUseCase(repository: videoFeedGetIt<VideoFeedRepository>()),
  );

  // Cubits
  videoFeedGetIt.registerFactory<VideoFeedCubit>(
    () => VideoFeedCubit(
      fetchVideosUseCase: videoFeedGetIt<FetchVideosUseCase>(),
      fetchMoreVideosUseCase: videoFeedGetIt<FetchMoreVideosUseCase>(),
    ),
  );
}
