import '../models/sutra_table_of_contents.dart';

/// 功德利益句子数据
class MeritBenefitSentence {
  /// 句子原文
  final String text;
  
  /// NLP识别得分（越高表示功德利益相关性越强）
  final double score;
  
  /// 所在段落索引
  final int paragraphIndex;
  
  /// 所属章节（可选）
  final SutraChapter? chapter;

  const MeritBenefitSentence({
    required this.text,
    required this.score,
    required this.paragraphIndex,
    this.chapter,
  });
}

/// 功德利益提取结果
class MeritBenefitData {
  /// 所有功德利益句子（按得分降序）
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
