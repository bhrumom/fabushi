class FavoriteItem {
  final String id;
  final String title;
  final String description;
  final String? textContent;
  final String? filePath;
  final DateTime favoritedAt;
  final String contentType; // 'video' or 'text'

  FavoriteItem({
    required this.id,
    required this.title,
    this.description = '',
    this.textContent,
    this.filePath,
    required this.favoritedAt,
    required this.contentType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'textContent': textContent,
    'filePath': filePath,
    'favoritedAt': favoritedAt.toIso8601String(),
    'contentType': contentType,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    textContent: json['textContent'] as String?,
    filePath: json['filePath'] as String?,
    favoritedAt: json['favoritedAt'] != null
        ? DateTime.parse(json['favoritedAt'] as String)
        : DateTime.now(),
    contentType: json['contentType'] as String? ?? 'text',
  );
}
