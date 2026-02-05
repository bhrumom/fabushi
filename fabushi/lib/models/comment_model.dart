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
  final String? mainPractice; // 用户的主修功课
  final String? attachmentPath; // 附件路径
  final String? attachmentType; // 'audio' | 'video' | null

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
    this.mainPractice,
    this.attachmentPath,
    this.attachmentType,
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
      mainPractice: json['main_practice'],
      attachmentPath: json['attachment_path'],
      attachmentType: json['attachment_type'],
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
      'main_practice': mainPractice,
      'attachment_path': attachmentPath,
      'attachment_type': attachmentType,
    };
  }

  String get displayName => nickname?.isNotEmpty == true ? nickname! : (username ?? '匿名用户');
}
