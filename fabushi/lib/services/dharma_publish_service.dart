import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum DharmaComposerTarget { global, platform }

enum DharmaPublishPlatform {
  wechatOfficial,
  xiaohongshu,
  douyin,
  weibo,
  toutiao,
  bilibili,
  kuaishou,
  zhihu,
}

class DharmaPublishPlatformInfo {
  final DharmaPublishPlatform platform;
  final String label;
  final String shortLabel;
  final String description;
  final String desktopUrl;
  final String? androidPackage;
  final bool titleRequired;
  final bool bodyRequired;

  const DharmaPublishPlatformInfo({
    required this.platform,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.desktopUrl,
    required this.androidPackage,
    this.titleRequired = true,
    this.bodyRequired = true,
  });
}

extension DharmaPublishPlatformX on DharmaPublishPlatform {
  DharmaPublishPlatformInfo get info {
    switch (this) {
      case DharmaPublishPlatform.wechatOfficial:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.wechatOfficial,
          label: '微信公众号',
          shortLabel: '公众号',
          description: '打开公众号平台草稿入口，正文会复制到剪贴板。',
          desktopUrl: 'https://mp.weixin.qq.com/',
          androidPackage: 'com.tencent.mm',
        );
      case DharmaPublishPlatform.xiaohongshu:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.xiaohongshu,
          label: '小红书',
          shortLabel: '小红书',
          description: '移动端优先拉起小红书分享入口，桌面打开创作平台。',
          desktopUrl: 'https://creator.xiaohongshu.com/',
          androidPackage: 'com.xingin.xhs',
        );
      case DharmaPublishPlatform.douyin:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.douyin,
          label: '抖音',
          shortLabel: '抖音',
          description: '移动端优先拉起抖音分享入口，桌面打开抖音创作者服务平台。',
          desktopUrl: 'https://creator.douyin.com/',
          androidPackage: 'com.ss.android.ugc.aweme',
        );
      case DharmaPublishPlatform.weibo:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.weibo,
          label: '微博',
          shortLabel: '微博',
          description: '移动端优先拉起微博分享入口，桌面打开微博首页。',
          desktopUrl: 'https://weibo.com/',
          androidPackage: 'com.sina.weibo',
        );
      case DharmaPublishPlatform.toutiao:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.toutiao,
          label: '今日头条',
          shortLabel: '头条',
          description: '打开头条号后台，正文会复制到剪贴板。',
          desktopUrl: 'https://mp.toutiao.com/',
          androidPackage: 'com.ss.android.article.news',
        );
      case DharmaPublishPlatform.bilibili:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.bilibili,
          label: '哔哩哔哩',
          shortLabel: 'B站',
          description: '打开 B 站创作中心，正文会复制到剪贴板。',
          desktopUrl: 'https://member.bilibili.com/platform/home',
          androidPackage: 'tv.danmaku.bili',
        );
      case DharmaPublishPlatform.kuaishou:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.kuaishou,
          label: '快手',
          shortLabel: '快手',
          description: '移动端优先拉起快手分享入口，桌面打开快手创作者中心。',
          desktopUrl: 'https://cp.kuaishou.com/',
          androidPackage: 'com.smile.gifmaker',
        );
      case DharmaPublishPlatform.zhihu:
        return const DharmaPublishPlatformInfo(
          platform: DharmaPublishPlatform.zhihu,
          label: '知乎',
          shortLabel: '知乎',
          description: '打开知乎写作入口，正文会复制到剪贴板。',
          desktopUrl: 'https://www.zhihu.com/',
          androidPackage: 'com.zhihu.android',
        );
    }
  }
}

class DharmaPublishDraft {
  final String title;
  final String body;
  final String sourceUrl;
  final List<String> tags;
  final DateTime createdAt;

  const DharmaPublishDraft({
    required this.title,
    required this.body,
    required this.sourceUrl,
    required this.tags,
    required this.createdAt,
  });

  DharmaPublishDraft copyWith({
    String? title,
    String? body,
    String? sourceUrl,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return DharmaPublishDraft(
      title: title ?? this.title,
      body: body ?? this.body,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get fullText {
    final parts = <String>[
      if (title.trim().isNotEmpty) title.trim(),
      if (body.trim().isNotEmpty) body.trim(),
      if (sourceUrl.trim().isNotEmpty) '来源链接：${sourceUrl.trim()}',
      if (tags.isNotEmpty) tags.map((tag) => '#$tag').join(' '),
    ];
    return parts.join('\n\n');
  }

  String get bodyPreview {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) return normalized;
    return '${normalized.substring(0, 160)}...';
  }
}

class DharmaPublishResult {
  final DharmaPublishPlatform platform;
  final bool success;
  final String message;
  final List<String> steps;
  final List<String> screenshotPaths;

  const DharmaPublishResult({
    required this.platform,
    required this.success,
    required this.message,
    this.steps = const [],
    this.screenshotPaths = const [],
  });
}

class DharmaPublishService {
  static const MethodChannel _platformChannel = MethodChannel(
    'com.ombhrum.fabushi/platform_publish',
  );

  static const List<DharmaPublishPlatform> allPlatforms = [
    DharmaPublishPlatform.wechatOfficial,
    DharmaPublishPlatform.xiaohongshu,
    DharmaPublishPlatform.douyin,
    DharmaPublishPlatform.weibo,
    DharmaPublishPlatform.toutiao,
    DharmaPublishPlatform.bilibili,
    DharmaPublishPlatform.kuaishou,
    DharmaPublishPlatform.zhihu,
  ];

  DharmaPublishDraft buildDraftFromModel(
    dynamic model, {
    String fallbackText = '',
  }) {
    final sourceUrl = (model.selectedContentSourceUrl as String?)?.trim() ?? '';
    final preview = (model.selectedContentPreviewText as String?)?.trim() ?? '';
    final title = (model.selectedContentTitle as String).trim();
    final text = preview.isNotEmpty ? preview : fallbackText.trim();

    return DharmaPublishDraft(
      title: _cleanTitle(title),
      body: _cleanBody(text),
      sourceUrl: sourceUrl,
      tags: _defaultTagsFor(text),
      createdAt: DateTime.now(),
    );
  }

  List<String> missingFields(
    DharmaPublishDraft draft,
    Iterable<DharmaPublishPlatform> platforms,
  ) {
    final requiresTitle = platforms.any(
      (platform) => platform.info.titleRequired,
    );
    final requiresBody = platforms.any(
      (platform) => platform.info.bodyRequired,
    );
    final missing = <String>[];

    if (requiresTitle && _needsTitleReview(draft)) missing.add('title');
    if (requiresBody && draft.body.trim().length < 12) missing.add('body');
    return missing;
  }

  String suggestTitle(DharmaPublishDraft draft) {
    final body = draft.body.trim();
    if (body.isEmpty) return '法布施分享';
    final sentences = body
        .split(RegExp(r'[。！？!?\n]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (sentences.isNotEmpty) {
      final first = sentences.first.replaceAll(RegExp(r'^[\s#：:，,]+'), '');
      if (first.length >= 8) {
        return first.length > 28 ? first.substring(0, 28) : first;
      }
    }
    final compact = body.replaceAll(RegExp(r'\s+'), '');
    if (compact.length <= 28) return compact;
    return compact.substring(0, 28);
  }

  String polishBody(DharmaPublishDraft draft) {
    final body = draft.body.trim();
    if (body.isEmpty) return body;
    final title = draft.title.trim().isEmpty
        ? suggestTitle(draft)
        : draft.title.trim();
    final tags = draft.tags.isEmpty ? ['法布施', '大乘'] : draft.tags;
    return [
      title,
      '',
      body,
      '',
      '愿以此功德，普及于一切。',
      tags.map((tag) => '#$tag').join(' '),
    ].join('\n');
  }

  String buildPreviewMarkdown(
    DharmaPublishDraft draft,
    Iterable<DharmaPublishPlatform> platforms,
  ) {
    final platformLabels = platforms.map((p) => p.info.label).join('、');
    return [
      '### 发布预览',
      '',
      '**平台**：$platformLabels',
      '**标题**：${draft.title.trim().isEmpty ? "待补充" : draft.title.trim()}',
      if (draft.sourceUrl.trim().isNotEmpty) '**来源**：${draft.sourceUrl.trim()}',
      '',
      draft.body.trim().isEmpty ? '_正文待补充_' : draft.body.trim(),
      if (draft.tags.isNotEmpty) '',
      if (draft.tags.isNotEmpty) draft.tags.map((tag) => '#$tag').join(' '),
    ].join('\n');
  }

  Future<List<DharmaPublishResult>> publishDraft({
    required DharmaPublishDraft draft,
    required Iterable<DharmaPublishPlatform> platforms,
  }) async {
    final results = <DharmaPublishResult>[];
    await Clipboard.setData(ClipboardData(text: draft.fullText));

    for (final platform in platforms) {
      results.add(await _publishOne(draft, platform));
    }

    return results;
  }

  Future<DharmaPublishResult> _publishOne(
    DharmaPublishDraft draft,
    DharmaPublishPlatform platform,
  ) async {
    final info = platform.info;
    final steps = <String>['已生成 ${info.label} 发布草稿', '已复制标题、正文、来源链接和标签到剪贴板'];

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final response = await _platformChannel
            .invokeMethod<dynamic>('shareToPlatform', {
              'packageName': info.androidPackage,
              'platformName': info.label,
              'title': draft.title,
              'text': draft.fullText,
              'url': draft.sourceUrl,
            });
        final map = response is Map ? response : const <dynamic, dynamic>{};
        final success = map['success'] == true;
        final message = (map['message'] ?? '').toString();
        steps.add(message.isEmpty ? '已尝试拉起 ${info.label}' : message);
        return DharmaPublishResult(
          platform: platform,
          success: success,
          message: message.isEmpty ? '已拉起 ${info.label} 分享/发布入口' : message,
          steps: steps,
        );
      } on MissingPluginException {
        steps.add('当前构建未启用 Android 平台发布通道，改为打开网页入口');
      } on PlatformException catch (error) {
        steps.add('拉起 ${info.label} App 失败：${error.message ?? error.code}');
      }
    }

    final uri = Uri.tryParse(info.desktopUrl);
    if (uri == null) {
      steps.add('平台入口地址无效');
      return DharmaPublishResult(
        platform: platform,
        success: false,
        message: '${info.label} 平台入口地址无效',
        steps: steps,
      );
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    steps.add(
      launched
          ? '已打开 ${info.label} 网页发布入口，登录态由系统浏览器/平台侧保存'
          : '未能自动打开 ${info.label} 网页入口，请手动访问 ${info.desktopUrl}',
    );
    return DharmaPublishResult(
      platform: platform,
      success: launched,
      message: launched
          ? '已打开 ${info.label} 发布入口，草稿内容已复制，可粘贴后确认发布'
          : '未能打开 ${info.label} 发布入口，草稿内容已复制',
      steps: steps,
    );
  }

  bool _needsTitleReview(DharmaPublishDraft draft) {
    final title = draft.title.trim();
    if (title.length < 4) return true;
    if (title.startsWith('http://') || title.startsWith('https://')) {
      return true;
    }
    if (draft.sourceUrl.trim().isEmpty) return false;
    final uri = Uri.tryParse(draft.sourceUrl.trim());
    if (uri == null) return false;
    return title == uri.host || title == 'link';
  }

  String _cleanTitle(String title) {
    final normalized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 60) return normalized;
    return normalized.substring(0, 60);
  }

  String _cleanBody(String text) {
    return text
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  List<String> _defaultTagsFor(String text) {
    final tags = <String>['法布施', '大乘'];
    if (text.contains('佛') || text.contains('菩萨')) tags.add('佛法');
    if (text.contains('禅') || text.contains('修行')) tags.add('修行');
    return tags.toSet().toList();
  }
}
