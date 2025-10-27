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
    if (_lastDocument == null) {
      return const Right([]);
    }

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
      Query query = _firestore
          .collection('videos')
          .orderBy('timestamp', descending: false)
          .orderBy(FieldPath.documentId, descending: false)
          .limit(2);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final snapshot = await query.get();
      final videos = <VideoEntity>[];

      // 添加视频内容
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        videos.addAll(
          snapshot.docs
              .map((doc) => VideoResponseModel.fromFirestore(doc).toEntity())
              .toList(),
        );
      }

      // 如果没有视频，返回纯文本信息流
      if (videos.isEmpty) {
        print('No videos found, loading text content...');
        try {
          // 获取多个文本内容
          for (int i = 0; i < 5; i++) {
            final textData = await _textService.getRandomTextContent();
            if (textData != null) {
              print('Loaded text content: ${textData['title']}');
              videos.add(VideoEntity(
                id: 'text_${DateTime.now().millisecondsSinceEpoch}_$i',
                username: textData['title'] ?? '佛法文本',
                description: '点击头像阅读全文',
                videoUrl: '',
                profileImageUrl: 'https://via.placeholder.com/100',
                likeCount: 0,
                commentCount: 0,
                shareCount: 0,
                timestamp: DateTime.now(),
                contentType: ContentType.text,
                textContent: textData['content'],
              ));
              await Future.delayed(const Duration(milliseconds: 10));
            }
          }
          print('Total text content loaded: ${videos.length}');
        } catch (e) {
          print('Error loading text content: $e');
          return Left('Failed to load text content: $e');
        }
      } else {
        // 有视频时，混合文本内容（每3个视频插入1个文本）
        if (_textContentIndex % 3 == 0) {
          try {
            final textData = await _textService.getRandomTextContent();
            if (textData != null) {
              final textEntity = VideoEntity(
                id: 'text_${DateTime.now().millisecondsSinceEpoch}',
                username: textData['title'] ?? '佛法文本',
                description: '点击头像阅读全文',
                videoUrl: '',
                profileImageUrl: 'https://via.placeholder.com/100',
                likeCount: 0,
                commentCount: 0,
                shareCount: 0,
                timestamp: DateTime.now(),
                contentType: ContentType.text,
                textContent: textData['content'],
              );
              videos.insert(videos.length ~/ 2, textEntity);
            }
          } catch (e) {
            print('Error adding text content: $e');
          }
        }
      }
      _textContentIndex++;

      return Right(videos);
    } on FirebaseException catch (e) {
      return Left('Firestore error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      return Left('Error processing video data: $e');
    }
  }
}
