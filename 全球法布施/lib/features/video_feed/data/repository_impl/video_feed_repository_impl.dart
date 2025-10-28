import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:global_dharma_sharing/features/video_feed/data/models/response/video_response_model.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:global_dharma_sharing/features/video_feed/domain/repositories/video_feed_repository.dart';
import 'package:global_dharma_sharing/services/cloudflare_text_service.dart';
import 'package:fpdart/fpdart.dart';

class VideoFeedRepositoryImpl implements VideoFeedRepository {
  VideoFeedRepositoryImpl({
    required FirebaseFirestore firestore,
    required CloudflareTextService textService,
  })  : _firestore = firestore,
        _textService = textService;

  final FirebaseFirestore _firestore;
  final CloudflareTextService _textService;
  DocumentSnapshot? _lastDocument;
  int _textContentIndex = 0;
  static const bool _enableVideoFeed = false;

  @override
  Future<Either<String, List<VideoEntity>>> fetchVideos() async {
    try {
      // Reset pagination state for a fresh fetch
      _lastDocument = null;
      return await _fetchVideosHelper();
    } on FirebaseException catch (e) {
      return Left('Failed to fetch videos: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return const Left('An unexpected error occurred while fetching videos');
    }
  }

  @override
  Future<Either<String, List<VideoEntity>>> fetchMoreVideos() async {
    try {
      return await _fetchVideosHelper(startAfterDocument: _lastDocument);
    } on FirebaseException catch (e) {
      return Left('Failed to fetch more videos: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return const Left('An unexpected error occurred while fetching more videos');
    }
  }

  Future<Either<String, List<VideoEntity>>> _fetchVideosHelper({
    DocumentSnapshot? startAfterDocument,
  }) async {
    try {
      final videos = <VideoEntity>[];

      // 仅在启用时查询视频
      if (_enableVideoFeed) {
        Query query = _firestore
            .collection('videos')
            .orderBy('timestamp', descending: false)
            .orderBy(FieldPath.documentId, descending: false)
            .limit(2);

        if (startAfterDocument != null) {
          query = query.startAfterDocument(startAfterDocument);
        }

        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
          videos.addAll(
            snapshot.docs
                .map((doc) => VideoResponseModel.fromFirestore(doc).toEntity())
                .toList(),
          );
        }
      }

      // 并行加载文本内容
      final textCount = 3;
      print('开始加载 $textCount 个文本内容...');
      final textFutures = List.generate(
        textCount,
        (i) => _textService.getRandomTextContent(),
      );
      
      final textResults = await Future.wait(
        textFutures,
        eagerError: false,
      );
      
      int successCount = 0;
      for (var i = 0; i < textResults.length; i++) {
        final textData = textResults[i];
        if (textData != null) {
          videos.add(VideoEntity(
            id: 'text_${DateTime.now().millisecondsSinceEpoch}_$i',
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
          ));
          successCount++;
        }
      }
      print('成功加载 $successCount 个文本内容，总计 ${videos.length} 个项目');
      _textContentIndex++;

      return Right(videos);
    } on FirebaseException catch (e) {
      return Left('Firestore error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return Left('Error processing video data: $e');
    }
  }
}
