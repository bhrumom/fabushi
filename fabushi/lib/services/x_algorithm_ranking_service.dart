import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/merit_benefit.dart';
import '../models/sutra_table_of_contents.dart';

/// 内部结构：被召回的句子片段
class _CandidateSentence {
  final String text;
  final int paragraphIndex;
  final int startOffset;
  final int endOffset;
  final bool isInNetworkFollower; // 是否紧跟高权重的上下文拓扑节点（如"佛言"）
  double score = 0.0;

  _CandidateSentence({
    required this.text,
    required this.paragraphIndex,
    required this.startOffset,
    required this.endOffset,
    this.isInNetworkFollower = false,
  });
}

/// 基于 X 开源推荐系统架构的三阶段漏斗打分引擎
/// 100% 纯端侧计算，0 模型显存占用，< 10ms 毫秒出结果
class XAlgorithmRankingService {
  static XAlgorithmRankingService? _instance;
  static XAlgorithmRankingService get instance =>
      _instance ??= XAlgorithmRankingService._();
  XAlgorithmRankingService._();

  // === SimClusters (语义簇特征字典) ===
  // 建立极品功德的特征词簇（类似推荐系统的话题类别）
  final _clusters = [
    {'灭罪', '消业', '除障', '解脱', '重罪', '清净', '无间', '罪业', '业障', '灭除'},
    {'富贵', '财宝', '福报', '丰饶', '无尽', '珍宝', '求财', '得大财富', '大富贵', '财物'},
    {
      '长寿',
      '无病',
      '延命',
      '安乐',
      '寿命',
      '康强',
      '除病',
      '愈疾',
      '寿命长远',
      '延年',
      '病之所侵损',
      '恼害',
    },
    {'智慧', '聪明', '开悟', '菩提', '辩才', '正觉', '得大智慧', '智慧明了', '得大聪明', '心开晓'},
    {'往生', '极乐', '净土', '莲华', '不退转', '生善处', '生天', '生尊贵家', '往生极乐'},
    {'功德', '利益', '果报', '福事', '无量无边', '不可思议', '殊胜', '功德聚'},
    {'拥护', '庇佑', '救护', '卫护', '守护', '忆念', '不为', '得胜', '无畏', '安稳'},
    {'消灭', '不能害', '不能烧', '不能伤', '不能溺', '不损害', '免灾', '不能侵害'},
  ];

  // === Engagement Signals (强互动特征) ===
  final _promiseWords = {
    '即得',
    '皆获',
    '必定',
    '决定',
    '速成就',
    '不堕',
    '皆得',
    '即生',
    '能令',
    '悉皆',
    '能成',
    '常为',
  };

  // === Topology Network (上下文图谱) ===
  final _buddhaNetwork = {'佛言', '佛告', '尔时世尊', '世尊言', '菩萨白佛言', '佛说是经'};

  // 缓存机制，避免重复计算
  final _fullTextCache = <int, MeritBenefitData>{};

  Future<MeritBenefitData> analyzeFullText(
    String fullText,
    SutraTableOfContents toc,
  ) async {
    final hash = fullText.hashCode;
    if (_fullTextCache.containsKey(hash)) {
      debugPrint('🚀 X-Algo: 命中全局打分缓存，0ms返回');
      return _fullTextCache[hash]!;
    }

    final stopwatch = Stopwatch()..start();

    // Stage 1: Candidate Sourcing (候选圈点与在网拓扑建立)
    final candidates = _sourceCandidates(fullText);
    debugPrint('🚀 X-Algo: Sourcing 阶段召回 ${candidates.length} 个基础句');

    // Stage 2: Heavy Ranking (特征漏斗深度打分)
    final ranked = _rankCandidates(candidates);

    // Stage 3: Heuristics & Filtering (启发式过滤截断)
    final filtered = _heuristicFilter(ranked);
    debugPrint('🚀 X-Algo: Filtering 阶段输出 ${filtered.length} 个高质量功德句');

    // 组装业务层需要的结果
    final allSentences = <MeritBenefitSentence>[];
    for (final c in filtered) {
      final chapter = toc.getCurrentChapter(c.paragraphIndex);
      allSentences.add(
        MeritBenefitSentence(
          text: c.text,
          paragraphIndex: c.paragraphIndex,
          startOffset: c.startOffset,
          endOffset: c.endOffset,
          chapter: chapter,
        ),
      );
    }

    final byChapter = <SutraChapter?, List<MeritBenefitSentence>>{};
    for (final sentence in allSentences) {
      byChapter.putIfAbsent(sentence.chapter, () => []).add(sentence);
    }

    stopwatch.stop();
    debugPrint('⏱️ X-Algo 引擎总打分耗时: ${stopwatch.elapsedMilliseconds}ms');

    final result = MeritBenefitData(
      sentences: allSentences,
      byChapter: byChapter,
    );
    _fullTextCache[hash] = result;
    return result;
  }

  void clearCache() => _fullTextCache.clear();

  // --------------------------------------------------------------------------
  // Stage 1: Candidate Sourcing
  // 按照长句截断，并传递上下文的拓扑网络权重 (前人是"佛言"，后人沾光)
  List<_CandidateSentence> _sourceCandidates(String text) {
    final paragraphs = text.split(RegExp(r'[\n]+'));
    final candidates = <_CandidateSentence>[];

    // 中文分句正则（包含引号内的句子）
    final sentenceRegex = RegExp(
      r'([^，。！？、；：""'
      '「」『』【】《》〈〉\n]+)',
    );

    bool currentNetworkActive = false; // 当前网格拓扑激活状态

    for (int pIndex = 0; pIndex < paragraphs.length; pIndex++) {
      final paragraph = paragraphs[pIndex];
      if (paragraph.trim().isEmpty) continue;

      final matches = sentenceRegex.allMatches(paragraph);

      for (final match in matches) {
        final sentenceText = match.group(0)!;
        final start = match.start;
        final end = match.end;
        final len = sentenceText.trim().length;

        // 丢弃过短的水词汇，或者全数字字母
        if (len < 3 || !RegExp(r'[\u4e00-\u9fff]').hasMatch(sentenceText)) {
          continue;
        }

        // 检查自身是否是拓扑激活节点 (例如"佛告舍利弗")
        bool isActivator = _buddhaNetwork.any((w) => sentenceText.contains(w));
        if (isActivator) {
          currentNetworkActive = true;
          // 本身是节点叙述语，一般不是功德，因此跳过，但点亮了网络
          continue;
        }

        candidates.add(
          _CandidateSentence(
            text: sentenceText.trim(),
            paragraphIndex: pIndex,
            startOffset: start,
            endOffset: end,
            isInNetworkFollower: currentNetworkActive,
          ),
        );
      }

      // 段落结束，拓扑能量稍微衰减（如果跨段，就不一定是佛在连续说了）
      // 这里简化处理：每段结束关闭拓扑状态
      currentNetworkActive = false;
    }

    return candidates;
  }

  // --------------------------------------------------------------------------
  // Stage 2: Heavy Ranking
  // 利用特征矩阵与多因子乘法模型，给出精准的推荐打分
  List<_CandidateSentence> _rankCandidates(
    List<_CandidateSentence> candidates,
  ) {
    for (final cand in candidates) {
      final text = cand.text;
      double score = 0.0;

      // Feature 1: SimCluster Density (簇击中密度基准分)
      int clusterHits = 0;
      for (final cluster in _clusters) {
        for (final word in cluster) {
          if (text.contains(word)) {
            score += 2.0;
            clusterHits++;
          }
        }
      }

      // 未击中任何核心利益簇，分数为0
      if (clusterHits == 0) {
        cand.score = 0.0;
        continue;
      }

      // Feature 2: Engagement Multiplier (承诺词引发的强力升权)
      bool hasPromise = _promiseWords.any((w) => text.contains(w));
      if (hasPromise) {
        score *= 1.5; // X-Algo 中的 Replying/Like 极致权重
      }

      // Feature 3: In-Network Boost (环境拓扑加成)
      if (cand.isInNetworkFollower) {
        score *= 1.2; // 如果是佛直接给出的许诺，权重提升
      }

      // Feature 4: Content Length Heuristics (长图文特性)
      final len = text.length;
      if (len > 8 && len < 25) {
        // 佛教四字、五字、七字排比句长度最佳，加上连接词大概 10~20
        score *= 1.1;
      } else if (len > 30) {
        // 太长可能是连贯叙事，缺乏凝练度
        score *= 0.9;
      }

      cand.score = score;
    }

    // 降序排列
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  // --------------------------------------------------------------------------
  // Stage 3: Heuristics & Filtering
  // 截断阈值、去重与作者（章节）多样性控制
  // 增加 “滑动窗口平滑聚合 (Contagion Grouping)” 以完美支持连续神仙名字排比句
  List<_CandidateSentence> _heuristicFilter(List<_CandidateSentence> ranked) {
    // 1. 恢复原始文本顺序
    final sequential = List<_CandidateSentence>.from(ranked)
      ..sort((a, b) {
        if (a.paragraphIndex != b.paragraphIndex) {
          return a.paragraphIndex.compareTo(b.paragraphIndex);
        }
        return a.startOffset.compareTo(b.startOffset);
      });

    final mergedBlocks = <_CandidateSentence>[];

    // 2. 核心算法：SimCluster Contagion (滑动窗口聚合)
    // 根据句子的原次序遍历，只要遇到高分功德句，就开启一个 Block（合并窗口）。
    // 在这个 Block 内，遇到低分句（0分或低分），容忍度 ( Gap ) 减 1。
    // 如果容忍度降为 0 且没有新的高分句续命，关闭当前 Block。
    // 如此一来，高分句之间的长段神仙名字排比句也会被作为大整体打包提取。

    int currentBlockStart = -1;
    int currentBlockEnd = -1;
    int gapTolerance = 0;
    const int maxGap = 6; // 最大容忍间隔的非功德句子数（神名排比非常长）
    int currentParagraph = -1;

    for (int i = 0; i < sequential.length; i++) {
      final cand = sequential[i];

      // 如果跨段落，强制结算当前 Block
      if (cand.paragraphIndex != currentParagraph) {
        if (currentBlockStart != -1) {
          _commitBlock(
            sequential,
            currentBlockStart,
            currentBlockEnd,
            mergedBlocks,
          );
          currentBlockStart = -1;
        }
        currentParagraph = cand.paragraphIndex;
        gapTolerance = 0;
      }

      final isHighScorer = cand.score >= 1.5;

      if (currentBlockStart == -1) {
        if (isHighScorer) {
          currentBlockStart = i;
          currentBlockEnd = i;
          gapTolerance = maxGap;
        }
      } else {
        if (isHighScorer) {
          currentBlockEnd = i;
          gapTolerance = maxGap;
        } else {
          gapTolerance--;
          if (gapTolerance <= 0) {
            _commitBlock(
              sequential,
              currentBlockStart,
              currentBlockEnd,
              mergedBlocks,
            );
            currentBlockStart = -1;
          }
        }
      }
    }

    if (currentBlockStart != -1) {
      _commitBlock(
        sequential,
        currentBlockStart,
        currentBlockEnd,
        mergedBlocks,
      );
    }

    // 3. 过滤长度，过于短的伪功德 Block 丢弃
    return mergedBlocks.where((b) => b.text.length >= 8).toList();
  }

  void _commitBlock(
    List<_CandidateSentence> seq,
    int startIdx,
    int endIdx,
    List<_CandidateSentence> out,
  ) {
    if (startIdx < 0 || endIdx < startIdx) return;

    final first = seq[startIdx];
    final last = seq[endIdx];

    final buffer = StringBuffer();
    for (int i = startIdx; i <= endIdx; i++) {
      buffer.write(seq[i].text);
      if (i < endIdx) buffer.write('，');
    }

    double totalScore = 0;
    for (int i = startIdx; i <= endIdx; i++) totalScore += seq[i].score;

    // 如果该合并块实质上非常短且得分极微弱，则当作杂质抛弃
    if (startIdx == endIdx && totalScore < 2.0) return;

    out.add(
      _CandidateSentence(
        text: buffer.toString(),
        paragraphIndex: first.paragraphIndex,
        startOffset: first.startOffset,
        endOffset: last.endOffset,
        isInNetworkFollower: first.isInNetworkFollower,
      )..score = totalScore,
    );
  }
}
