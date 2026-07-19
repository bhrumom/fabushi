import 'dart:convert';

import 'package:http/http.dart' as http;

typedef MiniAppCapabilityProgress = void Function(Map<String, dynamic> update);

/// Browser hosts cannot open UDP sockets. A plugin must provide explicit HTTPS
/// direct-delivery targets; each request remains an MCP host capability and is
/// still subject to the same user confirmation as native UDP.
class MiniAppHostCapabilityBridge {
  const MiniAppHostCapabilityBridge();

  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> request, {
    required MiniAppCapabilityProgress onProgress,
  }) async {
    final capability = request['capability']?.toString() ?? '';
    final params = request['params'] is Map
        ? Map<String, dynamic>.from(request['params'] as Map)
        : <String, dynamic>{};
    if (request['transport'] != 'mcp-host-bridge' ||
        capability != 'network.send') {
      return {
        'handled': false,
        'capability': capability,
        'reason': 'Web 宿主只处理带显式 HTTPS 目标的 network.send',
      };
    }
    final targets =
        (params['httpTargets'] as List?)
            ?.map((value) => Uri.tryParse(value.toString()))
            .whereType<Uri>()
            .where((uri) => uri.scheme == 'https' && uri.host.isNotEmpty)
            .toList(growable: false) ??
        const <Uri>[];
    if (targets.isEmpty) {
      return {
        'handled': false,
        'capability': capability,
        'channel': 'http-direct',
        'reason': 'Web 运行时没有收到经过宿主策略允许的 httpTargets',
      };
    }
    final payload = jsonEncode({
      'payload': params['payload']?.toString() ?? '',
      'taskId': params['taskId']?.toString() ?? 'mahayana-web',
    });
    final failures = <Map<String, dynamic>>[];
    var sent = 0;
    for (final target in targets) {
      try {
        final response = await http.post(
          target,
          headers: const {'content-type': 'application/json'},
          body: payload,
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError('HTTP ${response.statusCode}');
        }
        sent += 1;
        onProgress({
          'progress': sent,
          'total': targets.length,
          'message': 'HTTP 已直送至 ${target.host}',
        });
      } catch (error) {
        failures.add({'target': target.toString(), 'error': error.toString()});
      }
    }
    return {
      'handled': true,
      'ok': failures.isEmpty,
      'capability': capability,
      'channel': 'http-direct',
      'sentTargets': sent,
      'failedTargets': failures,
    };
  }
}
