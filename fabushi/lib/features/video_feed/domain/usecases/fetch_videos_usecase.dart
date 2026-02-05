import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/repositories/video_feed_repository.dart';
import 'package:fpdart/fpdart.dart';

class FetchVideosUseCase {
  FetchVideosUseCase({required VideoFeedRepository repository}) : _repository = repository;

  final VideoFeedRepository _repository;

  Future<Either<String, List<VideoEntity>>> call() {
    return _repository.fetchVideos();
  }
}
