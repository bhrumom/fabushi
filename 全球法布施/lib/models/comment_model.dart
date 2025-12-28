class CommentModel {
  final int id;
  final String videoId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final int? parentId;
  final int likeCount;
  final String? username;
  final String? nickname;
  final String? avatar;
  final String? tag; // 'ganying' | 'fayuan' | null

  CommentModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.likeCount = 0,
    this.username,
    this.nickname,
    this.avatar,
    this.tag,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      // 兼容 content_id 和 video_id
      videoId: json['content_id'] ?? json['video_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      parentId: json['parent_id'],
      likeCount: json['like_count'] ?? 0,
      username: json['username'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      tag: json['tag'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_id': videoId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'parent_id': parentId,
      'like_count': likeCount,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'tag': tag,
    };
  }

  String get displayName => nickname?.isNotEmpty == true ? nickname! : (username ?? '匿名用户');
}
