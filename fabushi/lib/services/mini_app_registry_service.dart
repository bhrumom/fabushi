import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mini_app_model.dart';
import 'codex_plugin_catalog.dart';
import 'mahayana_sdk.dart';

class MiniAppRegistryService {
  MiniAppRegistryService();

  static const String _cacheKey = 'mcp_plugin_registry_latest_good_v2';

  Future<MiniAppRegistry> loadRegistry({bool forceRefresh = false}) async {
    MiniAppRegistry registry;
    if (!forceRefresh) {
      final cached = await _readCachedRegistry();
      if (cached != null) {
        registry = cached;
        final merged = await _mergeLocalCodexPlugins(registry);
        await _writeCachedRegistry(merged);
        return merged;
      }
    }

    try {
      final decoded = await MahayanaSdk.instance.execute(const {
        '@type': 'mahayana.miniapps.registry',
      });
      registry = _registryFromPlugins(decoded);
      if (registry.bots.isEmpty || registry.miniApps.isEmpty) {
        throw StateError('registry is empty');
      }
    } catch (_) {
      final cached = await _readCachedRegistry();
      registry = cached ?? defaultMiniAppRegistry();
    }
    final merged = await _mergeLocalCodexPlugins(
      registry,
      forceRefresh: forceRefresh,
    );
    await _writeCachedRegistry(merged);
    return merged;
  }

  MiniAppRegistry _registryFromPlugins(Map<String, dynamic> payload) {
    final plugins = (payload['plugins'] as List? ?? const [])
        .whereType<Map>()
        .map((plugin) => Map<String, dynamic>.from(plugin))
        .toList(growable: false);
    final bots = <MiniAppBot>[];
    final manifests = <MiniAppManifest>[];
    for (final plugin in plugins) {
      final id = plugin['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final title = plugin['title']?.toString().trim() ?? id;
      final description = plugin['description']?.toString().trim() ?? '';
      final kind = switch (id) {
        'global-dharma' => MiniAppBotKind.globalDharma,
        'faliu-flashcards' => MiniAppBotKind.flashcards,
        'platform-publish' => MiniAppBotKind.platformPublish,
        'bot-father' => MiniAppBotKind.botFather,
        'mahayana-assistant' => MiniAppBotKind.assistant,
        _ => MiniAppBotKind.thirdParty,
      };
      final bot = MiniAppBot(
        botId: 'plugin.$id',
        title: title,
        subtitle: description,
        initials: title.substring(0, 1),
        iconKey: switch (kind) {
          MiniAppBotKind.globalDharma => 'public',
          MiniAppBotKind.flashcards => 'flashcards',
          MiniAppBotKind.platformPublish => 'publish',
          MiniAppBotKind.botFather => 'bot_father',
          MiniAppBotKind.assistant => 'assistant',
          MiniAppBotKind.thirdParty => 'apps',
        },
        avatarColor: const Color(0xFF3D8BFF),
        // Welcome content is optional and comes from the read-only MCP home
        // contract when the conversation is first opened.
        greeting: '',
        inputHint: '输入 / 查看 MCP Tools',
        miniAppId: id,
        kind: kind,
        permissions: const [],
        source: MiniAppSource.official,
      );
      bots.add(bot);
      manifests.add(
        MiniAppManifest(
          miniAppId: id,
          botId: bot.botId,
          title: title,
          subtitle: description,
          entryUrl: '',
          version: plugin['version']?.toString() ?? '1.0.0',
          permissions: const [],
          surfaces: const ['homePinned', 'chatPanel'],
          theme: 'mcpApp',
          signature: plugin['pluginId']?.toString() ?? id,
          reviewStatus: MiniAppReviewStatus.trusted,
          source: MiniAppSource.official,
        ),
      );
    }
    return MiniAppRegistry(
      schemaVersion: payload['schemaVersion'] is int
          ? payload['schemaVersion'] as int
          : 1,
      hostApiVersion: 'mcp-2025-06-18',
      bots: bots,
      miniApps: manifests,
      signature: 'mcp:${plugins.map((plugin) => plugin['pluginId']).join(',')}',
      updatedAt:
          DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Future<MiniAppRegistry> _mergeLocalCodexPlugins(
    MiniAppRegistry registry, {
    bool forceRefresh = false,
  }) async {
    List<CodexPluginDescriptor> localPlugins;
    try {
      localPlugins = await CodexPluginCatalogService.instance.listPlugins(
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      return registry;
    }
    if (localPlugins.isEmpty) return registry;

    final bots = [...registry.bots];
    final manifests = [...registry.miniApps];
    final botIndexes = <String, int>{
      for (var index = 0; index < bots.length; index++)
        normalizeCodexPluginId(bots[index].miniAppId): index,
    };
    final manifestIndexes = <String, int>{
      for (var index = 0; index < manifests.length; index++)
        normalizeCodexPluginId(manifests[index].miniAppId): index,
    };

    for (final plugin in localPlugins) {
      final id = normalizeCodexPluginId(plugin.id);
      if (id.isEmpty) continue;
      final title = plugin.title.trim().isEmpty ? id : plugin.title.trim();
      final subtitle = plugin.description.trim().isEmpty
          ? _localPluginSubtitle(plugin)
          : plugin.description.trim();
      final botIndex = botIndexes[id];
      final previousBot = botIndex == null ? null : bots[botIndex];
      final kind = previousBot?.kind ?? _kindForPlugin(id);
      final source = previousBot?.source ?? MiniAppSource.marketplace;
      final bot = MiniAppBot(
        botId: previousBot?.botId ?? 'plugin.$id',
        title: title,
        subtitle: subtitle,
        initials:
            previousBot?.initials ?? String.fromCharCode(title.runes.first),
        iconKey: previousBot?.iconKey ?? _iconForKind(kind),
        avatarColor: previousBot?.avatarColor ?? const Color(0xFF3D8BFF),
        greeting: previousBot?.greeting ?? '',
        inputHint: previousBot?.inputHint ?? '输入消息，或输入 / 查看 MCP Tools',
        miniAppId: id,
        kind: kind,
        permissions: previousBot?.permissions ?? const [],
        source: source,
      );
      if (botIndex == null) {
        botIndexes[id] = bots.length;
        bots.add(bot);
      } else {
        bots[botIndex] = bot;
      }

      final manifestIndex = manifestIndexes[id];
      final previousManifest = manifestIndex == null
          ? null
          : manifests[manifestIndex];
      final manifest = MiniAppManifest(
        miniAppId: id,
        botId: bot.botId,
        title: title,
        subtitle: subtitle,
        entryUrl: previousManifest?.entryUrl ?? '',
        version: previousManifest?.version ?? 'local',
        permissions: previousManifest?.permissions ?? const [],
        surfaces:
            previousManifest?.surfaces ?? const ['homePinned', 'chatPanel'],
        theme: previousManifest?.theme ?? 'mcpApp',
        signature: previousManifest?.signature ?? 'local-plugin:$id',
        reviewStatus:
            previousManifest?.reviewStatus ?? MiniAppReviewStatus.approved,
        source: previousManifest?.source ?? source,
        pluginPath: plugin.rootPath,
        uiEntryPath: plugin.uiEntryPath ?? '',
        skills: plugin.skills,
        mcpServers: plugin.mcpServers,
      );
      if (manifestIndex == null) {
        manifestIndexes[id] = manifests.length;
        manifests.add(manifest);
      } else {
        manifests[manifestIndex] = manifest;
      }
    }

    return MiniAppRegistry(
      schemaVersion: registry.schemaVersion,
      hostApiVersion: registry.hostApiVersion,
      bots: bots,
      miniApps: manifests,
      signature:
          '${registry.signature}|local:${localPlugins.map((plugin) => plugin.id).join(',')}',
      updatedAt: DateTime.now(),
    );
  }

  String _localPluginSubtitle(CodexPluginDescriptor plugin) {
    final parts = <String>[];
    if (plugin.skills.isNotEmpty) parts.add('${plugin.skills.length} Skills');
    if (plugin.mcpServers.isNotEmpty) {
      parts.add('${plugin.mcpServers.length} MCP');
    }
    return parts.isEmpty ? 'Codex 插件机器人' : parts.join(' · ');
  }

  MiniAppBotKind _kindForPlugin(String id) {
    return switch (id) {
      'global-dharma' => MiniAppBotKind.globalDharma,
      'faliu-flashcards' => MiniAppBotKind.flashcards,
      'platform-publish' => MiniAppBotKind.platformPublish,
      'bot-father' => MiniAppBotKind.botFather,
      'mahayana-assistant' => MiniAppBotKind.assistant,
      _ => MiniAppBotKind.thirdParty,
    };
  }

  String _iconForKind(MiniAppBotKind kind) {
    return switch (kind) {
      MiniAppBotKind.globalDharma => 'public',
      MiniAppBotKind.flashcards => 'flashcards',
      MiniAppBotKind.platformPublish => 'publish',
      MiniAppBotKind.botFather => 'bot_father',
      MiniAppBotKind.assistant => 'assistant',
      MiniAppBotKind.thirdParty => 'apps',
    };
  }

  Future<MiniAppRegistry?> _readCachedRegistry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final registry = MiniAppRegistry.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (registry.bots.isEmpty || registry.miniApps.isEmpty) return null;
      return registry;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedRegistry(MiniAppRegistry registry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(registry.toJson()));
    } catch (_) {
      // Cache failures should never block the app shell.
    }
  }
}
