import 'package:flutter/foundation.dart';
import '../features/video_feed/domain/entities/video_entity.dart';

/// 内容过滤服务
///
/// 满足 App Store Guideline 1.2 要求的「方法来过滤不当内容」
/// 提供关键词匹配过滤，拦截色情、暴力、仇恨言论等不当内容
class ContentFilterService {
  static final ContentFilterService _instance = ContentFilterService._();
  factory ContentFilterService() => _instance;
  ContentFilterService._();

  /// 违禁关键词集合（不当内容）
  /// 包含中英文违禁词，覆盖色情、暴力、仇恨言论等分类
  static const Set<String> _objectionableKeywords = {
    // 色情 / 淫秽
    '色情', '淫秽', '裸体', '性爱', '黄色视频', '成人内容', '援交',
    'porn', 'pornography', 'nude', 'nudity', 'obscene', 'explicit',
    // 暴力 / 血腥
    '杀人', '自杀', '砍人', '爆炸', '暴力', '恐怖袭击',
    'kill', 'murder', 'suicide', 'violence', 'terrorist',
    // 仇恨言论
    '种族歧视', '歧视', '辱骂', '滚出', '死去', '去死',
    'racist', 'racism', 'hate speech',
    // 骚扰 / 欺凌
    '威胁', '恐吓', '骚扰', '欺凌',
    'threaten', 'harass', 'bully',
    // 诈骗 / 非法
    '洗钱', '贩毒', '走私', '诈骗',
    'scam', 'fraud', 'drug trafficking',
  };

  /// 检查文本是否包含不当内容
  ///
  /// 返回 `true` 表示包含不当内容，应被过滤
  static bool containsObjectionableContent(String? text) {
    if (text == null || text.isEmpty) return false;
    final lowerText = text.toLowerCase();
    for (final keyword in _objectionableKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        debugPrint('🚫 内容过滤：检测到违禁词 "$keyword"');
        return true;
      }
    }
    return false;
  }

  /// 过滤视频/文本内容列表，移除含不当内容的条目
  static List<VideoEntity> filterVideos(List<VideoEntity> videos) {
    return videos.where((video) {
      // 检查文本内容
      if (containsObjectionableContent(video.textContent)) return false;
      // 检查标题/描述
      if (containsObjectionableContent(video.description)) return false;
      if (containsObjectionableContent(video.username)) return false;
      return true;
    }).toList();
  }
}
