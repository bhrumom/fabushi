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
  int? _telegramClientId;
  int? _telegramSelfUserId;

  bool get isAvailable => _runtime.isAvailable;
  String? get loadError => _runtime.loadError;

  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> command, {
    String? model,
    String? responsesBaseUrl,
  }) {
    final modelName = model?.trim();
    final baseUrl = responsesBaseUrl?.trim();
    return _runtime.execute({
      ...command,
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
    await execute(const {'@type': 'mahayana.runtime.status'});
  }

  /// Executes a same-origin platform request inside Rust. Flutter never sees
  /// the bearer or refresh credential; `authenticated` only selects whether
  /// Rust should attach its current encrypted session.
  Future<Map<String, dynamic>> platformRequest({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return execute({
      '@type': 'mahayana.platform.request',
      'method': method,
      'path': path,
      'query': ?query,
      'body': ?body,
      'authenticated': authenticated,
    });
  }

  /// Runs a Mini App message through the Rust Runtime while leaving only the
  /// final human approval choice to Flutter. MCP discovery, tool routing,
  /// entitlement checks, execution, and approval state remain in Rust/Codex.
  Future<Map<String, dynamic>> miniAppChat({
    required String pluginId,
    required String message,
    required Future<bool> Function(Map<String, dynamic> request) onApproval,
    void Function(Map<String, dynamic> progress)? onProgress,
  }) async {
    final conversationId = 'miniapp:$pluginId';
    final accepted = await _runtime.executeRuntime({
      '@type': 'mahayana.conversation.send',
      'conversationId': conversationId,
      'text': message,
    });
    final operationId = accepted['operationId']?.toString();
    if (operationId == null || operationId.isEmpty) {
      throw StateError('Mahayana Runtime did not accept the Mini App message.');
    }
    final buffer = StringBuffer();
    Map<String, dynamic>? completedMessage;
    while (true) {
      final event = await _runtime.receive();
      if (event == null || event['operationId']?.toString() != operationId) {
        continue;
      }
      switch (event['@type']?.toString()) {
        case 'mahayana.message.delta':
          buffer.write(event['delta']?.toString() ?? '');
          break;
        case 'mahayana.message.completed':
          if (event['message'] is Map) {
            completedMessage = Map<String, dynamic>.from(
              event['message'] as Map,
            );
          }
          break;
        case 'mahayana.approval.requested':
          final approvalId = event['approvalId']?.toString();
          if (approvalId != null && approvalId.isNotEmpty) {
            final approved = await onApproval(event);
            await _runtime.resolveApproval(
              approvalId,
              approved ? 'approve_session' : 'decline',
            );
          }
          break;
        case 'mahayana.plugin.progress':
          onProgress?.call(event);
          break;
        case 'mahayana.operation.completed':
          return {
            'operationId': operationId,
            'conversationId': conversationId,
            'message':
                completedMessage?['text']?.toString() ?? buffer.toString(),
            'data': ?completedMessage,
            'embedded': true,
          };
        case 'mahayana.operation.failed':
          throw StateError(
            event['message']?.toString() ??
                'Mahayana Mini App operation failed.',
          );
      }
    }
  }

  Future<void> clearSession() async {
    if (!isAvailable) return;
    await execute(const {'@type': 'mahayana.auth.logout'});
  }

  void reportSessionSyncFailure(Object error) {
    debugPrint('大乘 SDK 登录会话同步失败: $error');
  }
}
