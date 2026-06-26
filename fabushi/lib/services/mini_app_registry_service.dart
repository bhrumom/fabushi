import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../models/mini_app_model.dart';

class MiniAppRegistryService {
  MiniAppRegistryService({
    http.Client? httpClient,
    Future<String?> Function()? tokenProvider,
  }) : _httpClient = httpClient ?? http.Client(),
       _tokenProvider = tokenProvider;

  static const String _cacheKey = 'mini_app_registry_latest_good_v1';

  final http.Client _httpClient;
  final Future<String?> Function()? _tokenProvider;

  Future<MiniAppRegistry> loadRegistry({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _readCachedRegistry();
      if (cached != null) return cached;
    }

    try {
      final token = await _tokenProvider?.call();
      final uri = AppConfig.buildBackendUri('/api/miniapps/registry');
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('registry request failed: ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw StateError('registry payload is not an object');
      }
      final registry = MiniAppRegistry.fromJson(
        Map<String, dynamic>.from(decoded['registry'] as Map? ?? decoded),
      );
      if (registry.bots.isEmpty || registry.miniApps.isEmpty) {
        throw StateError('registry is empty');
      }
      await _writeCachedRegistry(registry);
      return registry;
    } catch (_) {
      final cached = await _readCachedRegistry();
      return cached ?? defaultMiniAppRegistry();
    }
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
