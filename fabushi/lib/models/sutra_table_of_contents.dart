/// 经文目录模型
/// 
/// 用于解析和存储经文的目录结构（卷、品）
library;

/// 章节类型枚举
enum ChapterType {
  /// 卷 - 如"卷第一"、"卷上"
  volume,
  /// 品 - 如"序品第一"、"方便品第二"
  chapter,
  /// 段落标记 - 如明显的分段标题
  section,
}

/// 经文章节数据
class SutraChapter {
  /// 章节标题（如"法会圣众第一"）
  final String title;
  
  /// 章节类型
  final ChapterType type;
  
  /// 在原文中的字符起始位置
  final int startPosition;
  
  /// 对应的段落索引
  final int paragraphIndex;
  
  /// 层级（0=卷，1=品，2=节）
  final int level;

  const SutraChapter({
    required this.title,
    required this.type,
    required this.startPosition,
    required this.paragraphIndex,
    required this.level,
  });

  /// 是否为卷级别
  bool get isVolume => type == ChapterType.volume;
  
  /// 是否为品级别
  bool get isChapter => type == ChapterType.chapter;
}

/// 经文目录
class SutraTableOfContents {
  /// 经文标题
  final String sutraTitle;
  
  /// 章节列表
  final List<SutraChapter> chapters;
  
  /// 段落文本列表（用于定位）
  final List<String> paragraphs;

  const SutraTableOfContents({
    required this.sutraTitle,
    required this.chapters,
    required this.paragraphs,
  });

  /// 是否有有效目录
  bool get hasValidToc => chapters.isNotEmpty;

  /// 获取卷列表
  List<SutraChapter> get volumes => 
      chapters.where((c) => c.isVolume).toList();

  /// 获取品列表
  List<SutraChapter> get chapterList => 
      chapters.where((c) => c.isChapter).toList();

  /// 根据段落索引获取当前章节
  SutraChapter? getCurrentChapter(int paragraphIndex) {
    SutraChapter? current;
    for (final chapter in chapters) {
      if (chapter.paragraphIndex <= paragraphIndex) {
        current = chapter;
      } else {
        break;
      }
    }
    return current;
  }

  /// 获取当前章节索引
  int getCurrentChapterIndex(int paragraphIndex) {
    for (int i = chapters.length - 1; i >= 0; i--) {
      if (chapters[i].paragraphIndex <= paragraphIndex) {
        return i;
      }
    }
    return 0;
  }

  /// 智能解析经文目录
  /// 
  /// 识别模式：
  /// - 卷：`XX经卷第X`、`卷第X`、`卷上/中/下`
  /// - 品：`XX品第X`、`第X品`
  static SutraTableOfContents parse(String content, String sutraTitle) {
    final chapters = <SutraChapter>[];
    final rawParagraphs = content.split(RegExp(r'[\n]+'));
    
    // 过滤空段落，与 TextPreprocessor 保持一致
    final paragraphs = <String>[];
    final rawToProcessedIndex = <int, int>{}; // 原始索引 -> 处理后索引的映射
    
    for (int i = 0; i < rawParagraphs.length; i++) {
      if (rawParagraphs[i].trim().isNotEmpty) {
        rawToProcessedIndex[i] = paragraphs.length;
        paragraphs.add(rawParagraphs[i]);
      }
    }
    
    // 中文数字映射
    const chineseNumbers = '一二三四五六七八九十百千';
    
    // 正则表达式模式
    // 卷模式：匹配 "经卷第X"、"卷第X"、"卷上/中/下"
    final volumePatterns = [
      RegExp(r'([^\n]*经卷[第]?[' + chineseNumbers + r']+)'),
      RegExp(r'([^\n]*卷[第]?[' + chineseNumbers + r']+)'),
      RegExp(r'([^\n]*[卷][上中下])'),
    ];
    
    // 品模式：匹配 "XX品第X"、"第X品"
    final chapterPatterns = [
      RegExp(r'([\u4e00-\u9fff]+品[第]?[' + chineseNumbers + r']+)'),
      RegExp(r'([第][' + chineseNumbers + r']+品[\u4e00-\u9fff]*)'),
    ];
    
    int currentPosition = 0;
    
    for (int rawIndex = 0; rawIndex < rawParagraphs.length; rawIndex++) {
      final paragraph = rawParagraphs[rawIndex].trim();
      if (paragraph.isEmpty) {
        currentPosition += rawParagraphs[rawIndex].length + 1; // +1 for newline
        continue;
      }
      
      // 获取处理后的段落索引
      final processedIndex = rawToProcessedIndex[rawIndex]!;
      
      // 检测卷
      for (final pattern in volumePatterns) {
        final match = pattern.firstMatch(paragraph);
        if (match != null) {
          final title = match.group(1)!.trim();
          // 验证是否是有效的卷标题（通常在行首或是整行）
          if (_isValidChapterTitle(paragraph, title)) {
            chapters.add(SutraChapter(
              title: title,
              type: ChapterType.volume,
              startPosition: currentPosition,
              paragraphIndex: processedIndex,
              level: 0,
            ));
            break; // 找到一个卷就跳过
          }
        }
      }
      
      // 检测品
      for (final pattern in chapterPatterns) {
        final match = pattern.firstMatch(paragraph);
        if (match != null) {
          final title = match.group(1)!.trim();
          if (_isValidChapterTitle(paragraph, title)) {
            // 避免与卷重复添加
            final isDuplicate = chapters.any((c) => 
                c.paragraphIndex == processedIndex && c.title == title);
            if (!isDuplicate) {
              chapters.add(SutraChapter(
                title: title,
                type: ChapterType.chapter,
                startPosition: currentPosition,
                paragraphIndex: processedIndex,
                level: 1,
              ));
            }
            break;
          }
        }
      }
      
      currentPosition += rawParagraphs[rawIndex].length + 1;
    }
    
    // 按位置排序
    chapters.sort((a, b) => a.startPosition.compareTo(b.startPosition));
    
    return SutraTableOfContents(
      sutraTitle: sutraTitle,
      chapters: chapters,
      paragraphs: paragraphs,
    );
  }

  /// 验证是否为有效的章节标题
  /// 章节标题通常较短，且位于段落开头
  static bool _isValidChapterTitle(String paragraph, String title) {
    // 标题长度限制（通常不超过30字）
    if (title.length > 30) return false;
    
    // 检查是否在段落开头附近
    final index = paragraph.indexOf(title);
    if (index > 10) return false; // 标题距离段落开头不应太远
    
    // 排除在引用或括号内的情况
    final beforeTitle = paragraph.substring(0, index);
    if (beforeTitle.contains('《') && !beforeTitle.contains('》')) return false;
    if (beforeTitle.contains('"') && !beforeTitle.contains('"')) return false;
    
    return true;
  }
}
