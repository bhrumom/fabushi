import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/merit_benefit.dart';
import '../models/sutra_table_of_contents.dart';
import 'curated_merit_benefit_service.dart';
import 'x_algorithm_ranking_service.dart';

/// 功德利益识别服务 (人工校订语义单元 + X-Algo 推荐模型)
///
/// 先尝试使用人工校订的完整语义单元数据。若当前经文没有校订数据，
/// 则回退到 XAlgorithmRankingService 的端侧轻量化推荐漏斗算法。
class MeritBenefitService {
  static MeritBenefitService? _instance;
  static MeritBenefitService get instance =>
      _instance ??= MeritBenefitService._();
  MeritBenefitService._();

  final CuratedMeritBenefitService _curatedService =
      CuratedMeritBenefitService.instance;
  final XAlgorithmRankingService _rankingService =
      XAlgorithmRankingService.instance;

  /// 新算法100%本地离线执行，无需模型加载，始终就绪
  bool get isModelReady => true;

  /// 从经文全文中提取功德利益句子。
  ///
  /// 对已校订经典，返回完整语义单元，避免把“胜彼”“此前福德”等
  /// 依赖上下文的句子拆成令人迷惑的片段；其他经典继续使用 X-Algo。
  Future<MeritBenefitData> extractFromText(
    String fullText,
    SutraTableOfContents toc,
  ) async {
    final curated = _curatedService.analyzeFullText(fullText, toc);
    if (curated != null) {
      debugPrint('📿 MeritBenefitService: 命中人工校订功德利益语义单元');
      return curated;
    }

    return _rankingService.analyzeFullText(fullText, toc);
  }

  /// 清除缓存
  void clearCache() {
    _rankingService.clearCache();
  }
}
