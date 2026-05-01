/// 感应/发愿帖子模型
class FeedPostModel {
  final int id;
  final String videoId;
  final String? videoTitle; // 原视频标题
  final String userId;
  final String content;
  final DateTime createdAt;
  final String tag; // 'ganying' | 'fayuan'
  final int likeCount;
  final String? username;
  final String? nickname;
  final String? avatar;

  FeedPostModel({
    required this.id,
    required this.videoId,
    this.videoTitle,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.tag,
    this.likeCount = 0,
    this.username,
    this.nickname,
    this.avatar,
  });

  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    return FeedPostModel(
      id: json['id'],
      videoId: json['video_id'] ?? '',
      videoTitle: json['video_title'],
      userId: json['user_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      tag: json['tag'],
      likeCount: json['like_count'] ?? 0,
      username: json['username'],
      nickname: json['nickname'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_id': videoId,
      'video_title': videoTitle,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'tag': tag,
      'like_count': likeCount,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
    };
  }

  String get displayName =>
      nickname?.isNotEmpty == true ? nickname! : (username ?? '匿名用户');

  bool get isGanying => tag == 'ganying';
  bool get isFayuan => tag == 'fayuan';

  String get tagDisplayName {
    switch (tag) {
      case 'ganying':
        return '感应';
      case 'fayuan':
        return '发愿';
      default:
        return '';
    }
  }
}
