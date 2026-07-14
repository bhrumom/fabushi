import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import 'miniapp/mahayana_codex_runtime.dart';

/// Flutter-facing entry point for the embedded Mahayana SDK.
///
/// Every platform sends the same `mahayana.*` JSON commands. Native shells
/// dispatch them through the C ABI, while Web dispatches them through WASM.
/// Product login and model configuration are bridge inputs used to create the
/// local Runtime; they are not copied into Codex auth storage.
class MahayanaSdk {
  MahayanaSdk._();

  static final MahayanaSdk instance = MahayanaSdk._();

  final MahayanaCodexRuntime _runtime = MahayanaCodexRuntime.instance;
  String? _lastSynchronizedToken;
  int? _telegramClientId;
  int? _telegramSelfUserId;

  bool get isAvailable => _runtime.isAvailable;
  String? get loadError => _runtime.loadError;

  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> command, {
    String? productSessionToken,
    String? model,
    String? responsesBaseUrl,
  }) {
    final token = productSessionToken?.trim();
    final modelName = model?.trim();
    final baseUrl = responsesBaseUrl?.trim();
    return _runtime.execute({
      ...command,
      if (token?.isNotEmpty == true) 'token': token,
      if (modelName?.isNotEmpty == true) 'model': modelName,
      if (_telegramClientId != null) 'telegramClientId': _telegramClientId,
      if (_telegramSelfUserId != null)
        'telegramSelfUserId': _telegramSelfUserId,
      'responsesBaseUrl': baseUrl?.isNotEmpty == true
          ? baseUrl
          : AppConfig.codexDeepSeekResponsesBaseUrl,
    });
  }

  /// Registers the platform's persistent Telegram client as a provider on the
  /// one Mahayana Runtime. Reconfiguration preserves the client; it does not
  /// create a second conversation Runtime.
  Future<void> attachTelegramClient({
    required int clientId,
    int selfUserId = 0,
  }) async {
    if (_telegramClientId == clientId && _telegramSelfUserId == selfUserId) {
      return;
    }
    _telegramClientId = clientId;
    _telegramSelfUserId = selfUserId;
    if (!isAvailable) return;
    await execute(const {
      '@type': 'mahayana.runtime.status',
    }, productSessionToken: _lastSynchronizedToken);
  }

  /// Makes an App-authenticated session available to the native CLI and
  /// invalidates any Runtime that was created under an older account.
  Future<void> synchronizeSession({
    required String token,
    Map<String, dynamic>? user,
    String provider = 'app',
  }) async {
    final normalized = token.trim();
    if (normalized.isEmpty || normalized == _lastSynchronizedToken) return;
    if (!isAvailable) return;
    await execute({
      '@type': 'mahayana.auth.session.sync',
      'token': normalized,
      'provider': provider,
      'user': ?user,
      'username': ?user?['username'],
      'email': ?user?['email'],
    });
    _lastSynchronizedToken = normalized;
  }

  Future<void> clearSession() async {
    _lastSynchronizedToken = null;
    if (!isAvailable) return;
    await execute(const {'@type': 'mahayana.auth.logout'});
  }

  void reportSessionSyncFailure(Object error) {
    debugPrint('大乘 SDK 登录会话同步失败: $error');
  }
}
