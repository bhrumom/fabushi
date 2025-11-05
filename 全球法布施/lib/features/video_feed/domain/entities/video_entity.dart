import 'package:equatable/equatable.dart';

enum ContentType { video, text }

class VideoEntity extends Equatable {
  const VideoEntity({
    required this.id,
    required this.username,
    required this.description,
    required this.videoUrl,
    required this.profileImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.timestamp,
    this.contentType = ContentType.video,
    this.textContent,
  });

  final String id;
  final String username;
  final String description;
  final String videoUrl;
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime timestamp;
  final ContentType contentType;
  final String? textContent;

  @override
  List<Object?> get props => [
    id,
    username,
    description,
    videoUrl,
    profileImageUrl,
    likeCount,
    commentCount,
    shareCount,
    timestamp,
    contentType,
    textContent,
  ];
}
