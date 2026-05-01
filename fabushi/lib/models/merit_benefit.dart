import '../models/sutra_table_of_contents.dart';

/// 功德利益句子数据
///
/// 包含句子原文及其在段落中的位置信息
class MeritBenefitSentence {
  /// 句子原文
  final String text;

  /// 所在段落索引
  final int paragraphIndex;

  /// 句子在段落中的起始位置（字符索引）
  final int startOffset;

  /// 句子在段落中的结束位置（字符索引）
  final int endOffset;

  /// 所属章节（可选）
  final SutraChapter? chapter;

  const MeritBenefitSentence({
    required this.text,
    required this.paragraphIndex,
    this.startOffset = 0,
    this.endOffset = 0,
    this.chapter,
  });

  /// 句子长度
  int get length => text.length;
}

/// 段落识别结果
///
/// 用于懒加载流式返回
class MeritBenefitParagraphResult {
  /// 段落索引
  final int paragraphIndex;

  /// 该段落中的功德利益句子
  final List<MeritBenefitSentence> sentences;

  /// 是否正在加载
  final bool isLoading;

  /// 是否已完成识别
  final bool isReady;

  const MeritBenefitParagraphResult({
    required this.paragraphIndex,
    required this.sentences,
    this.isLoading = false,
    this.isReady = false,
  });

  /// 是否找到功德利益句
  bool get hasMerit => sentences.isNotEmpty;
}

/// 功德利益提取结果
class MeritBenefitData {
  /// 所有功德利益句子
  final List<MeritBenefitSentence> sentences;

  /// 按章节分组的功德利益句子
  final Map<SutraChapter?, List<MeritBenefitSentence>> byChapter;

  /// 是否已完成分析
  final bool isAnalyzed;

  const MeritBenefitData({
    required this.sentences,
    required this.byChapter,
    this.isAnalyzed = true,
  });

  /// 空数据
  static const empty = MeritBenefitData(
    sentences: [],
    byChapter: {},
    isAnalyzed: false,
  );

  /// 功德利益句子总数
  int get totalCount => sentences.length;

  /// 章节数量
  int get chapterCount => byChapter.length;
}
