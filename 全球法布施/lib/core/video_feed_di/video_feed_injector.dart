import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:global_dharma_sharing/features/video_feed/data/repository_impl/video_feed_repository_impl.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/repositories/video_feed_repository.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_more_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/usecases/fetch_videos_usecase.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:global_dharma_sharing/services/cloudflare_text_service.dart';
import 'package:get_it/get_it.dart';

final videoFeedGetIt = GetIt.instance;

void setupVideoFeedDependencies() {
  // Firebase
  videoFeedGetIt.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  // Services
  videoFeedGetIt.registerLazySingleton<CloudflareTextService>(() => CloudflareTextService());

  // Repositories
  videoFeedGetIt.registerLazySingleton<VideoFeedRepository>(
    () => VideoFeedRepositoryImpl(
      firestore: videoFeedGetIt<FirebaseFirestore>(),
      textService: videoFeedGetIt<CloudflareTextService>(),
    ),
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
