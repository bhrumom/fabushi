import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/merit_benefit.dart';
import '../models/sutra_table_of_contents.dart';
import 'x_algorithm_ranking_service.dart';

/// 功德利益识别服务 (X-Algo 推荐模型重构版)
/// 
/// 封装 XAlgorithmRankingService，提供经文功德利益句子提取功能。
/// 彻底抛弃缓慢的 LLM 模型，采用端侧轻量化推荐漏斗算法。
class MeritBenefitService {
  static MeritBenefitService? _instance;
  static MeritBenefitService get instance => _instance ??= MeritBenefitService._();
  MeritBenefitService._();

  final XAlgorithmRankingService _rankingService = XAlgorithmRankingService.instance;
  
  /// 新算法100%本地离线执行，无需模型加载，始终就绪
  bool get isModelReady => true;

  /// 从经文全文中提取功德利益句子
  /// 
  /// 极致性能：直接调用全局缓存API，有缓存时 0ms 返回。
  /// 无缓存时，漏斗算法耗时 < 10ms。
  Future<MeritBenefitData> extractFromText(
    String fullText,
    SutraTableOfContents toc,
  ) async {
    return _rankingService.analyzeFullText(fullText, toc);
  }
  
  /// 清除缓存
  void clearCache() {
    _rankingService.clearCache();
  }
}
