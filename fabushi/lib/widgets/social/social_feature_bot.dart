import 'package:flutter/material.dart';

import '../../models/mini_app_model.dart';

/// 固定在社交联系人列表顶部的功能机器人。
enum SocialFeatureBotType {
  globalDharma,
  flashcards,
  platformPublish,
  assistant,
}

class SocialFeatureBot {
  const SocialFeatureBot({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.initials,
    required this.icon,
    required this.avatarColor,
    required this.destinationIndex,
    required this.greeting,
    required this.inputHint,
    this.botId,
    this.miniAppId,
    this.miniAppEntryUrl = '',
    this.kind,
    this.permissions = const [],
    this.source = MiniAppSource.official,
  });

  final SocialFeatureBotType type;
  final String? botId;
  final String? miniAppId;
  final String miniAppEntryUrl;
  final String title;
  final String subtitle;
  final String initials;
  final IconData icon;
  final Color avatarColor;
  final int destinationIndex;
  final String greeting;
  final String inputHint;
  final MiniAppBotKind? kind;
  final List<String> permissions;
  final MiniAppSource source;

  String get stableBotId => botId ?? type.name;
  String get stableMiniAppId => miniAppId ?? type.name;
  String get stableMiniAppEntryUrl => miniAppEntryUrl.trim();
  MiniAppBotKind get effectiveKind {
    final explicit = kind;
    if (explicit != null) return explicit;
    switch (type) {
      case SocialFeatureBotType.globalDharma:
        return MiniAppBotKind.globalDharma;
      case SocialFeatureBotType.flashcards:
        return MiniAppBotKind.flashcards;
      case SocialFeatureBotType.platformPublish:
        return MiniAppBotKind.platformPublish;
      case SocialFeatureBotType.assistant:
        return MiniAppBotKind.assistant;
    }
  }

  factory SocialFeatureBot.fromMiniApp(
    MiniAppBot bot, {
    required int index,
    MiniAppManifest? manifest,
  }) {
    final legacyType = switch (bot.kind) {
      MiniAppBotKind.globalDharma => SocialFeatureBotType.globalDharma,
      MiniAppBotKind.flashcards => SocialFeatureBotType.flashcards,
      MiniAppBotKind.platformPublish => SocialFeatureBotType.platformPublish,
      _ => SocialFeatureBotType.assistant,
    };
    return SocialFeatureBot(
      type: legacyType,
      botId: bot.botId,
      miniAppId: bot.miniAppId,
      miniAppEntryUrl: manifest?.entryUrl ?? '',
      title: bot.title,
      subtitle: bot.subtitle,
      initials: bot.initials,
      icon: bot.icon,
      avatarColor: bot.avatarColor,
      destinationIndex: index,
      greeting: bot.greeting,
      inputHint: bot.inputHint,
      kind: bot.kind,
      permissions: bot.permissions,
      source: bot.source,
    );
  }
}

extension SocialFeatureBotTypeX on SocialFeatureBotType {
  SocialFeatureBot get bot {
    switch (this) {
      case SocialFeatureBotType.globalDharma:
        return const SocialFeatureBot(
          type: SocialFeatureBotType.globalDharma,
          title: '全球法布施',
          subtitle: '地区、循环、场能都在对话框上方设置',
          initials: '法',
          icon: Icons.public,
          avatarColor: Color(0xFF4CAF7A),
          destinationIndex: 0,
          greeting: '把要分享的文字、链接或素材发给我，我会按上方选择的地区与模式启动全球法布施。',
          inputHint: '输入要法布施的文字/链接，或点 + 添加素材',
          botId: 'bot.global-dharma',
          miniAppId: 'official.global-dharma',
          kind: MiniAppBotKind.globalDharma,
          permissions: [
            'app.context',
            'bot.chat',
            'ui.native',
            'haptics.feedback',
            'auth.session',
            'payments.alipay',
            'files.pick',
            'network.http',
            'network.udp',
            'network.interfaces',
            'system.keepAwake',
            'hotspot.settings',
            'cloud.kv',
            'runtime.storage',
            'runtime.file',
            'globalDharma.delivery',
            'local.loopback',
            'fs.readWrite',
            'runtime.process',
            'share.chat',
          ],
        );
      case SocialFeatureBotType.flashcards:
        return const SocialFeatureBot(
          type: SocialFeatureBotType.flashcards,
          title: '背诵闪卡制作',
          subtitle: '随机挖空 / AI 制卡从顶部模式按钮选择',
          initials: '卡',
          icon: Icons.style_outlined,
          avatarColor: Color(0xFF7E57C2),
          destinationIndex: 1,
          greeting: '粘贴经文、文章正文或链接即可制作背诵闪卡。制卡模式请在上方按钮切换，不会再插入聊天选择消息。',
          inputHint: '粘贴链接或正文，发送后制作闪卡',
          botId: 'bot.flashcards',
          miniAppId: 'official.flashcards',
          kind: MiniAppBotKind.flashcards,
          permissions: [
            'app.context',
            'bot.chat',
            'ui.native',
            'haptics.feedback',
            'flashcards.create',
            'cloud.kv',
            'share.chat',
          ],
        );
      case SocialFeatureBotType.platformPublish:
        return const SocialFeatureBot(
          type: SocialFeatureBotType.platformPublish,
          title: '法布施到平台',
          subtitle: '选择平台后生成发布草稿并打开入口',
          initials: '发',
          icon: Icons.campaign_outlined,
          avatarColor: Color(0xFFFF9F43),
          destinationIndex: 2,
          greeting: '把要发布的正文或链接发给我，上方选择平台后，我会生成发布草稿、复制到剪贴板并打开对应平台入口。',
          inputHint: '输入要发布到平台的正文/链接',
          botId: 'bot.platform-publish',
          miniAppId: 'official.platform-publish',
          kind: MiniAppBotKind.platformPublish,
          permissions: [
            'app.context',
            'bot.chat',
            'ui.native',
            'haptics.feedback',
            'platform.publish',
            'files.pick',
            'fs.readWrite',
            'shell.execute',
            'browser.external',
            'cloud.kv',
            'share.chat',
          ],
        );
      case SocialFeatureBotType.assistant:
        return const SocialFeatureBot(
          type: SocialFeatureBotType.assistant,
          title: '大乘助理',
          subtitle: '原有 OpenClaw / AI / 桌面控制入口',
          initials: 'AI',
          icon: Icons.smart_toy_outlined,
          avatarColor: Color(0xFF3D8BFF),
          destinationIndex: 3,
          greeting: '继续使用原有大乘助理。',
          inputHint: '问问大乘',
          botId: 'bot.assistant',
          miniAppId: 'official.assistant',
          kind: MiniAppBotKind.assistant,
        );
    }
  }
}

List<SocialFeatureBot> defaultSocialMiniAppBots() {
  final registry = defaultMiniAppRegistry();
  return [
    for (var i = 0; i < registry.bots.length; i++)
      SocialFeatureBot.fromMiniApp(
        registry.bots[i],
        index: i,
        manifest: registry.manifestFor(registry.bots[i].miniAppId),
      ),
  ];
}
