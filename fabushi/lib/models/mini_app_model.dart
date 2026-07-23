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
  final String pluginPath;
  final String uiEntryPath;
  final List<String> skills;
  final List<String> mcpServers;

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
    this.pluginPath = '',
    this.uiEntryPath = '',
    this.skills = const [],
    this.mcpServers = const [],
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
      pluginPath: _readString(json, 'pluginPath'),
      uiEntryPath: _readString(json, 'uiEntryPath'),
      skills: _readStringList(json['skills']),
      mcpServers: _readStringList(json['mcpServers']),
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
    if (pluginPath.isNotEmpty) 'pluginPath': pluginPath,
    if (uiEntryPath.isNotEmpty) 'uiEntryPath': uiEntryPath,
    if (skills.isNotEmpty) 'skills': skills,
    if (mcpServers.isNotEmpty) 'mcpServers': mcpServers,
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
      greeting: _readString(json, 'greeting'),
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
    case 'approval':
      return Icons.verified_user_outlined;
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
  final definitions = <(String, String, String, String, MiniAppBotKind)>[
    ('global-dharma', '全球法布施', '法', 'public', MiniAppBotKind.globalDharma),
    ('faliu-flashcards', '法流记忆卡', '卡', 'flashcards', MiniAppBotKind.flashcards),
    (
      'platform-publish',
      '平台发布',
      '发',
      'publish',
      MiniAppBotKind.platformPublish,
    ),
    ('hermes-installer', 'Hermes 安装器', 'H', 'apps', MiniAppBotKind.thirdParty),
    ('bot-father', 'Bot Father', '父', 'bot_father', MiniAppBotKind.botFather),
    ('mahayana-assistant', '大乘助手', '助', 'assistant', MiniAppBotKind.assistant),
    (
      'chatgpt-auto-confirm',
      'ChatGPT 自动确认',
      '允',
      'approval',
      MiniAppBotKind.thirdParty,
    ),
  ];
  final bots = definitions
      .map(
        (definition) => MiniAppBot(
          botId: 'plugin.${definition.$1}',
          title: definition.$2,
          subtitle: 'MCP 插件',
          initials: definition.$3,
          iconKey: definition.$4,
          avatarColor: const Color(0xFF3D8BFF),
          greeting: '',
          inputHint: '输入 / 查看 MCP Tools',
          miniAppId: definition.$1,
          kind: definition.$5,
          permissions: const [],
          source: MiniAppSource.official,
        ),
      )
      .toList(growable: false);
  return MiniAppRegistry(
    schemaVersion: 1,
    hostApiVersion: 'mcp-2025-06-18',
    bots: bots,
    miniApps: [
      for (final bot in bots)
        MiniAppManifest(
          miniAppId: bot.miniAppId,
          botId: bot.botId,
          title: bot.title,
          subtitle: bot.subtitle,
          entryUrl: '',
          version: '1.0.0',
          permissions: const [],
          surfaces: const ['homePinned', 'chatPanel'],
          theme: 'mcpApp',
          signature: 'fabushi-official:${bot.miniAppId}',
          reviewStatus: MiniAppReviewStatus.trusted,
          source: MiniAppSource.official,
        ),
    ],
    signature: 'fabushi-official-mcp-v1',
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
