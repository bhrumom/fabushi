// Firebase/Firestore removed for Windows compatibility
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/repositories/video_feed_repository.dart';
import 'package:global_dharma_sharing/services/cloudflare_text_service.dart';
import 'package:fpdart/fpdart.dart';

class VideoFeedRepositoryImpl implements VideoFeedRepository {
  VideoFeedRepositoryImpl({
    required CloudflareTextService textService,
  }) : _textService = textService;

  final CloudflareTextService _textService;
  int _textContentIndex = 0;
  bool _isLoading = false;

  @override
  Future<Either<String, List<VideoEntity>>> fetchVideos() async {
    try {
      return await _fetchVideosHelper();
    } catch (e) {
      return const Left('An unexpected error occurred while fetching videos');
    }
  }

  @override
  Future<Either<String, List<VideoEntity>>> fetchMoreVideos() async {
    if (_isLoading) {
      print('已有加载任务进行中，跳过本次请求');
      return const Right([]);
    }
    try {
      _isLoading = true;
      final result = await _fetchVideosHelper();
      return result;
    } catch (e) {
      return const Left('An unexpected error occurred while fetching more videos');
    } finally {
      _isLoading = false;
    }
  }

  Future<Either<String, List<VideoEntity>>> _fetchVideosHelper() async {
    try {
      final videos = <VideoEntity>[];

      // 从预加载队列获取文本内容 (Firestore video feed disabled)
      final textCount = 2;

      for (int i = 0; i < textCount; i++) {
        final textData = await _textService.getRandomTextContent();

        if (textData != null) {
          final filePath = textData['filePath'] as String?;
          videos.add(
            VideoEntity(
              id: filePath ?? 'text_${DateTime.now().millisecondsSinceEpoch}_$i',
              username: textData['title'] ?? '佛法文本',
              description: '点击头像阅读全文',
              videoUrl: '',
              profileImageUrl: '',
              likeCount: 0,
              commentCount: 0,
              shareCount: 0,
              timestamp: DateTime.now(),
              contentType: ContentType.text,
              textContent: textData['content'],
              filePath: filePath,
            ),
          );
        }
      }

      print('加载成功: ${videos.length} 个内容');
      _textContentIndex++;

      return Right(videos);
    } catch (e) {
      return Left('Error processing video data: $e');
    }
  }
}
