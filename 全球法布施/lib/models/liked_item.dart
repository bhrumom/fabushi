class LikedItem {
  final String id;
  final String username;
  final String description;
  final String? videoUrl;
  final String? textContent;
  final String profileImageUrl;
  final DateTime likedAt;
  final String contentType; // 'video' or 'text'
  final String? filePath; // 文本内容的文件路径，用于热门页面加载

  LikedItem({
    required this.id,
    required this.username,
    required this.description,
    this.videoUrl,
    this.textContent,
    required this.profileImageUrl,
    required this.likedAt,
    required this.contentType,
    this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'description': description,
        'videoUrl': videoUrl,
        'textContent': textContent,
        'profileImageUrl': profileImageUrl,
        'likedAt': likedAt.toIso8601String(),
        'contentType': contentType,
        'filePath': filePath,
      };

  factory LikedItem.fromJson(Map<String, dynamic> json) => LikedItem(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        description: json['description'] as String? ?? '',
        videoUrl: json['videoUrl'] as String?,
        textContent: json['textContent'] as String?,
        profileImageUrl: json['profileImageUrl'] as String? ?? '',
        likedAt: json['likedAt'] != null 
            ? DateTime.parse(json['likedAt'] as String)
            : DateTime.now(),
        contentType: json['contentType'] as String? ?? 'text',
        filePath: json['filePath'] as String?,
      );
}

