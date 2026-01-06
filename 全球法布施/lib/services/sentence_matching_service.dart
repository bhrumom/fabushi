import 'package:flutter/foundation.dart';
import 'package:lpinyin/lpinyin.dart';

/// 智能句子匹配服务
/// 
/// 用于读诵模块的智能识别，将语音识别结果与目标经文句子进行拼音匹配，
/// 判断用户是否已念完当前句子。
class SentenceMatchingService {
  /// 匹配阈值：识别文本拼音覆盖目标句子拼音的百分比
  /// 达到此阈值且检测到静音端点时，判定为念完
  static const double matchThreshold = 0.50;
  
  /// 快速切换阈值：当匹配度非常高时可以更快切换
  static const double fastMatchThreshold = 0.70;
  
  /// 最小静音时长（毫秒）：检测到端点后需要等待的静音时长
  static const int minSilenceDurationMs = 300;
  
  /// 上次检测到端点的时间
  DateTime? _lastEndpointTime;
  
  /// 当前累计的识别文本
  String _accumulatedText = '';
  
  /// 重置状态（切换到新句子时调用）
  void reset() {
    _lastEndpointTime = null;
    _accumulatedText = '';
  }
  
  /// 计算识别文本与目标句子的匹配分数
  /// 
  /// 返回 0.0 ~ 1.0 之间的匹配度
  /// 算法：计算识别文本拼音序列在目标句子拼音序列中的最大连续覆盖率
  double calculateMatchScore(String recognizedText, String targetSentence) {
    if (recognizedText.isEmpty || targetSentence.isEmpty) {
      return 0.0;
    }
    
    // 提取纯中文字符
    final recognizedChinese = _extractChinese(recognizedText);
    final targetChinese = _extractChinese(targetSentence);
    
    if (recognizedChinese.isEmpty || targetChinese.isEmpty) {
      return 0.0;
    }
    
    // 转换为拼音（不带声调，用于模糊匹配）
    final recognizedPinyin = _toPinyinList(recognizedChinese);
    final targetPinyin = _toPinyinList(targetChinese);
    
    if (recognizedPinyin.isEmpty || targetPinyin.isEmpty) {
      return 0.0;
    }
    
    // 计算匹配度
    // 策略1：计算识别拼音在目标拼音中的最长公共子序列比例
    final lcsLength = _longestCommonSubsequenceLength(recognizedPinyin, targetPinyin);
    
    // 匹配度 = LCS长度 / 目标句子拼音长度
    final score = lcsLength / targetPinyin.length;
    
    return score.clamp(0.0, 1.0);
  }
  
  /// 判断是否应该自动切换到下一句
  /// 
  /// [recognizedText] 当前识别到的文本
  /// [targetSentence] 目标经文句子
  /// [isEndpoint] 是否检测到语音端点（静音）
  /// 
  /// 返回 true 表示应该切换到下一句
  bool shouldAdvanceToNext(String recognizedText, String targetSentence, bool isEndpoint) {
    // 累计识别文本（处理流式识别的增量）
    if (recognizedText.length > _accumulatedText.length) {
      _accumulatedText = recognizedText;
    }
    
    final score = calculateMatchScore(_accumulatedText, targetSentence);
    
    debugPrint('[SentenceMatching] 匹配度: ${(score * 100).toStringAsFixed(1)}%, '
        '识别: "$_accumulatedText", 目标: "$targetSentence", 端点: $isEndpoint');
    
    // 情况1：匹配度非常高（≥90%），直接切换
    if (score >= fastMatchThreshold) {
      debugPrint('[SentenceMatching] 高匹配度触发切换');
      return true;
    }
    
    // 情况2：匹配度达到阈值（≥75%）且检测到静音端点
    if (score >= matchThreshold && isEndpoint) {
      // 记录端点时间
      if (_lastEndpointTime == null) {
        _lastEndpointTime = DateTime.now();
        debugPrint('[SentenceMatching] 首次检测到端点，等待静音确认...');
        return false;
      }
      
      // 检查静音持续时间
      final silenceDuration = DateTime.now().difference(_lastEndpointTime!).inMilliseconds;
      if (silenceDuration >= minSilenceDurationMs) {
        debugPrint('[SentenceMatching] 确认念完，触发切换');
        return true;
      }
    } else {
      // 没有端点或匹配度不够，重置端点时间
      _lastEndpointTime = null;
    }
    
    return false;
  }
  
  /// 获取当前匹配进度（用于 UI 显示）
  /// 
  /// 返回 0.0 ~ 1.0 之间的进度值
  double getProgress(String recognizedText, String targetSentence) {
    return calculateMatchScore(recognizedText, targetSentence);
  }
  
  /// 提取字符串中的中文字符
  String _extractChinese(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      // 中文 Unicode 范围：\u4e00-\u9fff
      if (char >= 0x4e00 && char <= 0x9fff) {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }
  
  /// 将中文字符串转换为拼音列表（不带声调）
  List<String> _toPinyinList(String chinese) {
    final result = <String>[];
    for (final char in chinese.runes) {
      final charStr = String.fromCharCode(char);
      // 获取拼音（不带声调）
      final pinyin = PinyinHelper.getPinyinE(charStr, defPinyin: '');
      if (pinyin.isNotEmpty) {
        result.add(pinyin.toLowerCase());
      }
    }
    return result;
  }
  
  /// 计算两个列表的最长公共子序列长度
  /// 
  /// 使用动态规划算法
  int _longestCommonSubsequenceLength(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    
    // 优化：使用一维数组节省空间
    final dp = List<int>.filled(n + 1, 0);
    
    for (int i = 1; i <= m; i++) {
      int prev = 0;
      for (int j = 1; j <= n; j++) {
        final temp = dp[j];
        if (a[i - 1] == b[j - 1]) {
          dp[j] = prev + 1;
        } else {
          dp[j] = dp[j] > dp[j - 1] ? dp[j] : dp[j - 1];
        }
        prev = temp;
      }
    }
    
    return dp[n];
  }
  
  /// 计算当前朗读进度的提示文本
  String getProgressHint(double progress) {
    if (progress < 0.1) {
      return '请开始朗读...';
    } else if (progress < 0.3) {
      return '继续念...';
    } else if (progress < 0.5) {
      return '很好，继续...';
    } else if (progress < 0.7) {
      return '即将完成...';
    } else {
      return '念完了！';
    }
  }
}
