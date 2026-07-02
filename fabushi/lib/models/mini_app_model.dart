import 'package:flutter/material.dart';

enum MiniAppSource { official, sandbox, marketplace }

enum MiniAppReviewStatus { trusted, sandbox, pendingReview, approved, rejected }

enum MiniAppBotKind {
  globalDharma,
  flashcards,
  platformPublish,
  botFather,
  assistant,
  thirdParty,
}

class MiniAppManifest {
  final String miniAppId;
  final String botId;
  final String title;
  final String subtitle;
  final String entryUrl;
  final String version;
  final List<String> permissions;
  final List<String> surfaces;
  final String theme;
  final String signature;
  final MiniAppReviewStatus reviewStatus;
  final MiniAppSource source;

  const MiniAppManifest({
    required this.miniAppId,
    required this.botId,
    required this.title,
    required this.subtitle,
    required this.entryUrl,
    required this.version,
    required this.permissions,
    required this.surfaces,
    required this.theme,
    required this.signature,
    required this.reviewStatus,
    required this.source,
  });

  factory MiniAppManifest.fromJson(Map<String, dynamic> json) {
    return MiniAppManifest(
      miniAppId: _readString(json, 'miniAppId'),
      botId: _readString(json, 'botId'),
      title: _readString(json, 'title', fallback: '小程序'),
      subtitle: _readString(json, 'subtitle'),
      entryUrl: _readString(json, 'entryUrl'),
      version: _readString(json, 'version', fallback: '0.0.1'),
      permissions: _readStringList(json['permissions']),
      surfaces: _readStringList(json['surfaces']),
      theme: _readString(json, 'theme', fallback: 'telegramDark'),
      signature: _readString(json, 'signature'),
      reviewStatus: _reviewStatusFromString(json['reviewStatus']),
      source: _sourceFromString(json['source']),
    );
  }

  Map<String, dynamic> toJson() => {
    'miniAppId': miniAppId,
    'botId': botId,
    'title': title,
    'subtitle': subtitle,
    'entryUrl': entryUrl,
    'version': version,
    'permissions': permissions,
    'surfaces': surfaces,
    'theme': theme,
    'signature': signature,
    'reviewStatus': reviewStatus.storageValue,
    'source': source.storageValue,
  };

  bool get isTrustedOfficial =>
      source == MiniAppSource.official &&
      reviewStatus == MiniAppReviewStatus.trusted;
}

class MiniAppBot {
  final String botId;
  final String title;
  final String subtitle;
  final String initials;
  final String iconKey;
  final Color avatarColor;
  final String greeting;
  final String inputHint;
  final String miniAppId;
  final MiniAppBotKind kind;
  final List<String> permissions;
  final MiniAppSource source;

  const MiniAppBot({
    required this.botId,
    required this.title,
    required this.subtitle,
    required this.initials,
    required this.iconKey,
    required this.avatarColor,
    required this.greeting,
    required this.inputHint,
    required this.miniAppId,
    required this.kind,
    required this.permissions,
    required this.source,
  });

  factory MiniAppBot.fromJson(Map<String, dynamic> json) {
    return MiniAppBot(
      botId: _readString(json, 'botId'),
      title: _readString(json, 'title', fallback: '小程序机器人'),
      subtitle: _readString(json, 'subtitle'),
      initials: _readString(json, 'initials', fallback: '小'),
      iconKey: _readString(json, 'icon', fallback: 'apps'),
      avatarColor: _colorFromHex(_readString(json, 'avatarColor')),
      greeting: _readString(json, 'greeting', fallback: '你好，我是小程序机器人。'),
      inputHint: _readString(json, 'inputHint', fallback: '输入消息'),
      miniAppId: _readString(json, 'miniAppId'),
      kind: _botKindFromString(json['kind']),
      permissions: _readStringList(json['permissions']),
      source: _sourceFromString(json['source']),
    );
  }

  Map<String, dynamic> toJson() => {
    'botId': botId,
    'title': title,
    'subtitle': subtitle,
    'initials': initials,
    'icon': iconKey,
    'avatarColor': _hexFromColor(avatarColor),
    'greeting': greeting,
    'inputHint': inputHint,
    'miniAppId': miniAppId,
    'kind': kind.storageValue,
    'permissions': permissions,
    'source': source.storageValue,
  };

  IconData get icon => iconForMiniApp(iconKey);
}

class MiniAppRegistry {
  final int schemaVersion;
  final String hostApiVersion;
  final List<MiniAppBot> bots;
  final List<MiniAppManifest> miniApps;
  final String signature;
  final DateTime updatedAt;

  const MiniAppRegistry({
    required this.schemaVersion,
    required this.hostApiVersion,
    required this.bots,
    required this.miniApps,
    required this.signature,
    required this.updatedAt,
  });

  factory MiniAppRegistry.fromJson(Map<String, dynamic> json) {
    return MiniAppRegistry(
      schemaVersion: _readInt(json['schemaVersion']) ?? 1,
      hostApiVersion: _readString(json, 'hostApiVersion', fallback: '2.0'),
      bots: (json['bots'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => MiniAppBot.fromJson(Map<String, dynamic>.from(item)))
          .where((bot) => bot.botId.isNotEmpty)
          .toList(),
      miniApps: (json['miniApps'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => MiniAppManifest.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((app) => app.miniAppId.isNotEmpty)
          .toList(),
      signature: _readString(json, 'signature'),
      updatedAt:
          DateTime.tryParse(_readString(json, 'updatedAt')) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'hostApiVersion': hostApiVersion,
    'bots': bots.map((bot) => bot.toJson()).toList(),
    'miniApps': miniApps.map((app) => app.toJson()).toList(),
    'signature': signature,
    'updatedAt': updatedAt.toIso8601String(),
  };

  MiniAppManifest? manifestFor(String miniAppId) {
    for (final app in miniApps) {
      if (app.miniAppId == miniAppId) return app;
    }
    return null;
  }
}

extension MiniAppSourceX on MiniAppSource {
  String get storageValue {
    switch (this) {
      case MiniAppSource.official:
        return 'official';
      case MiniAppSource.sandbox:
        return 'sandbox';
      case MiniAppSource.marketplace:
        return 'marketplace';
    }
  }
}

extension MiniAppReviewStatusX on MiniAppReviewStatus {
  String get storageValue {
    switch (this) {
      case MiniAppReviewStatus.trusted:
        return 'trusted';
      case MiniAppReviewStatus.sandbox:
        return 'sandbox';
      case MiniAppReviewStatus.pendingReview:
        return 'pending_review';
      case MiniAppReviewStatus.approved:
        return 'approved';
      case MiniAppReviewStatus.rejected:
        return 'rejected';
    }
  }
}

extension MiniAppBotKindX on MiniAppBotKind {
  String get storageValue {
    switch (this) {
      case MiniAppBotKind.globalDharma:
        return 'global_dharma';
      case MiniAppBotKind.flashcards:
        return 'flashcards';
      case MiniAppBotKind.platformPublish:
        return 'platform_publish';
      case MiniAppBotKind.botFather:
        return 'bot_father';
      case MiniAppBotKind.assistant:
        return 'assistant';
      case MiniAppBotKind.thirdParty:
        return 'third_party';
    }
  }
}

IconData iconForMiniApp(String key) {
  switch (key) {
    case 'public':
      return Icons.public;
    case 'flashcards':
      return Icons.style_outlined;
    case 'publish':
      return Icons.campaign_outlined;
    case 'bot_father':
      return Icons.construction_outlined;
    case 'assistant':
      return Icons.smart_toy_outlined;
    case 'code':
      return Icons.code;
    case 'folder':
      return Icons.folder_outlined;
    default:
      return Icons.apps_outlined;
  }
}

MiniAppRegistry defaultMiniAppRegistry() {
  final now = DateTime.now();
  final permissions = <String>[
    'app.context',
    'bot.chat',
    'ui.native',
    'haptics.feedback',
    'auth.session',
    'wallet.balance',
    'payments.entitlement',
    'payments.fudeGold',
    'payments.alipay',
    'network.http',
    'network.udp',
    'network.interfaces',
    'system.keepAwake',
    'hotspot.settings',
    'flashcards.create',
    'platform.publish',
    'cloud.kv',
    'runtime.storage',
    'runtime.file',
    'globalDharma.delivery',
    'share.chat',
    'files.pick',
    'projects.read',
    'openclaw.status',
    'openclaw.chat',
    'local.loopback',
    'desktop.control',
    'fs.readWrite',
    'runtime.process',
    'shell.execute',
    'browser.external',
  ];
  final bots = <MiniAppBot>[
    MiniAppBot(
      botId: 'bot.global-dharma',
      title: '全球法布施',
      subtitle: '地区、循环、场能都在对话框上方设置',
      initials: '法',
      iconKey: 'public',
      avatarColor: const Color(0xFF4CAF7A),
      greeting: '把要分享的文字、链接或素材发给我，我会按上方选择的地区与模式启动全球法布施。',
      inputHint: '输入要法布施的文字/链接，或点 + 添加素材',
      miniAppId: 'official.global-dharma',
      kind: MiniAppBotKind.globalDharma,
      permissions: permissions,
      source: MiniAppSource.official,
    ),
    MiniAppBot(
      botId: 'bot.flashcards',
      title: '背诵闪卡制作',
      subtitle: '随机挖空 / AI 制卡从顶部模式按钮选择',
      initials: '卡',
      iconKey: 'flashcards',
      avatarColor: const Color(0xFF7E57C2),
      greeting: '粘贴经文、文章正文或链接即可制作背诵闪卡。制卡模式请在上方按钮切换。',
      inputHint: '粘贴链接或正文，发送后制作闪卡',
      miniAppId: 'official.flashcards',
      kind: MiniAppBotKind.flashcards,
      permissions: permissions,
      source: MiniAppSource.official,
    ),
    MiniAppBot(
      botId: 'bot.platform-publish',
      title: '法布施到平台',
      subtitle: '选择平台后生成发布草稿并打开入口',
      initials: '发',
      iconKey: 'publish',
      avatarColor: const Color(0xFFFF9F43),
      greeting: '把要发布的正文或链接发给我，上方选择平台后，我会生成发布草稿并打开对应平台入口。',
      inputHint: '输入要发布到平台的正文/链接',
      miniAppId: 'official.platform-publish',
      kind: MiniAppBotKind.platformPublish,
      permissions: permissions,
      source: MiniAppSource.official,
    ),
    MiniAppBot(
      botId: 'bot.father',
      title: '机器人之父',
      subtitle: '用对话生成个人沙箱小程序',
      initials: '父',
      iconKey: 'bot_father',
      avatarColor: const Color(0xFF3D8BFF),
      greeting: '告诉我你想要的小程序，我会生成 manifest、界面和权限声明，并放进你的个人沙箱。',
      inputHint: '描述你想创建的小程序',
      miniAppId: 'official.bot-father',
      kind: MiniAppBotKind.botFather,
      permissions: const ['app.context', 'bot.chat', 'miniapps.dev'],
      source: MiniAppSource.official,
    ),
  ];
  return MiniAppRegistry(
    schemaVersion: 1,
    hostApiVersion: '2.0',
    bots: bots,
    miniApps: [
      for (final bot in bots)
        MiniAppManifest(
          miniAppId: bot.miniAppId,
          botId: bot.botId,
          title: bot.title,
          subtitle: bot.subtitle,
          entryUrl:
              'https://fabushi-miniapps.pages.dev/miniapps/${bot.miniAppId}',
          version: '2.0.0',
          permissions: bot.permissions,
          surfaces: const ['homePinned', 'chatPanel'],
          theme: 'telegramDark',
          signature: 'builtin',
          reviewStatus: MiniAppReviewStatus.trusted,
          source: MiniAppSource.official,
        ),
    ],
    signature: 'builtin',
    updatedAt: now,
  );
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  return (json[key] ?? fallback).toString().trim();
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) {
        return item.isNotEmpty;
      })
      .toList(growable: false);
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

MiniAppSource _sourceFromString(Object? value) {
  switch (value?.toString()) {
    case 'sandbox':
      return MiniAppSource.sandbox;
    case 'marketplace':
      return MiniAppSource.marketplace;
    case 'official':
    default:
      return MiniAppSource.official;
  }
}

MiniAppReviewStatus _reviewStatusFromString(Object? value) {
  switch (value?.toString()) {
    case 'sandbox':
      return MiniAppReviewStatus.sandbox;
    case 'pending_review':
      return MiniAppReviewStatus.pendingReview;
    case 'approved':
      return MiniAppReviewStatus.approved;
    case 'rejected':
      return MiniAppReviewStatus.rejected;
    case 'trusted':
    default:
      return MiniAppReviewStatus.trusted;
  }
}

MiniAppBotKind _botKindFromString(Object? value) {
  switch (value?.toString()) {
    case 'global_dharma':
      return MiniAppBotKind.globalDharma;
    case 'flashcards':
      return MiniAppBotKind.flashcards;
    case 'platform_publish':
      return MiniAppBotKind.platformPublish;
    case 'bot_father':
      return MiniAppBotKind.botFather;
    case 'assistant':
      return MiniAppBotKind.assistant;
    case 'third_party':
    default:
      return MiniAppBotKind.thirdParty;
  }
}

Color _colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '').trim();
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final parsed = int.tryParse(hex, radix: 16);
  return Color(parsed ?? 0xFF3D8BFF);
}

String _hexFromColor(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
