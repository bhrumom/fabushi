/// 禅室修行功课模型
/// 
/// 存储用户选定的修行功课信息
/// 一旦选定后不可更改（锁定机制）
class MeditationPractice {
  /// 经文标题
  final String title;
  
  /// 文件路径（用于评论关联和内容加载）
  final String filePath;
  
  /// 选定时间
  final DateTime selectedAt;
  
  /// 是否已锁定（选定后即锁定）
  final bool isLocked;

  const MeditationPractice({
    required this.title,
    required this.filePath,
    required this.selectedAt,
    this.isLocked = true,
  });

  /// 从 JSON 创建
  factory MeditationPractice.fromJson(Map<String, dynamic> json) {
    return MeditationPractice(
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      selectedAt: DateTime.parse(json['selectedAt'] as String),
      isLocked: json['isLocked'] as bool? ?? true,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'title': title,
    'filePath': filePath,
    'selectedAt': selectedAt.toIso8601String(),
    'isLocked': isLocked,
  };

  /// 生成用于评论的 contentId
  /// 使用 filePath 的 hash 确保唯一性
  String get contentId => 'practice_${filePath.hashCode.abs()}';

  @override
  String toString() => 'MeditationPractice(title: $title, filePath: $filePath, isLocked: $isLocked)';
}

/// 可选修行功课列表项
/// 用于功课选择界面展示
class PracticeOption {
  final String title;
  final String filePath;
  final String? category;
  final String? description;

  const PracticeOption({
    required this.title,
    required this.filePath,
    this.category,
    this.description,
  });
}
