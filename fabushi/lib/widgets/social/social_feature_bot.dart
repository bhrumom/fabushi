import 'package:flutter/material.dart';

import '../../models/mini_app_model.dart';

/// 固定在社交联系人列表顶部的功能机器人。
enum SocialFeatureBotType {
  globalDharma,
  flashcards,
  platformPublish,
  hermesInstaller,
  botFather,
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
      case SocialFeatureBotType.hermesInstaller:
        return MiniAppBotKind.thirdParty;
      case SocialFeatureBotType.botFather:
        return MiniAppBotKind.botFather;
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
      MiniAppBotKind.botFather => SocialFeatureBotType.botFather,
      MiniAppBotKind.thirdParty when bot.miniAppId == 'hermes-installer' =>
        SocialFeatureBotType.hermesInstaller,
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
    final pluginId = switch (this) {
      SocialFeatureBotType.globalDharma => 'global-dharma',
      SocialFeatureBotType.flashcards => 'faliu-flashcards',
      SocialFeatureBotType.platformPublish => 'platform-publish',
      SocialFeatureBotType.hermesInstaller => 'hermes-installer',
      SocialFeatureBotType.botFather => 'bot-father',
      SocialFeatureBotType.assistant => 'mahayana-assistant',
    };
    final bots = defaultSocialMiniAppBots();
    return bots.firstWhere(
      (bot) => bot.stableMiniAppId == pluginId,
      orElse: () => bots.first,
    );
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
