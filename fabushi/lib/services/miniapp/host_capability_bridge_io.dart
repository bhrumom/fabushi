import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../udp_global_send_service.dart';

typedef MiniAppCapabilityProgress = void Function(Map<String, dynamic> update);

/// Executes the small, explicit set of OS capabilities that a local
/// CLI/WASM plugin cannot own. Plugins never receive a socket or process
/// handle; they receive only the serializable result of this bridge call.
class MiniAppHostCapabilityBridge {
  const MiniAppHostCapabilityBridge();

  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> request, {
    required MiniAppCapabilityProgress onProgress,
  }) async {
    if (request['transport'] != 'mcp-host-bridge') {
      return {'handled': false, 'reason': '不支持的宿主桥接协议'};
    }
    final capability = request['capability']?.toString() ?? '';
    final params = request['params'] is Map
        ? Map<String, dynamic>.from(request['params'] as Map)
        : <String, dynamic>{};
    return switch (capability) {
      'network.send' => _sendNetwork(params, onProgress),
      'network.udp.send' => _sendUdpDatagrams(params, onProgress),
      _ => Future.value({
        'handled': false,
        'capability': capability,
        'reason': '该能力需要由对应的宿主服务适配器处理',
      }),
    };
  }

  Future<Map<String, dynamic>> _sendNetwork(
    Map<String, dynamic> params,
    MiniAppCapabilityProgress onProgress,
  ) async {
    final explicitTargets = params['targets'];
    if (explicitTargets is List && explicitTargets.isNotEmpty) {
      return _sendUdpDatagrams(params, onProgress);
    }

    final payload = params['payload']?.toString() ?? '';
    if (payload.isEmpty) {
      return {
        'handled': true,
        'ok': false,
        'capability': 'network.send',
        'error': 'payload 不能为空',
      };
    }
    final bytes = Uint8List.fromList(utf8.encode(payload));
    final taskId = params['taskId']?.toString() ?? 'mahayana';
    final requestedCountries = (params['countryCodes'] as List?)
        ?.map((value) => value.toString().toUpperCase())
        .toList(growable: false);
    final logs = <String>[];
    var countriesSent = 0;
    var bytesSentMb = 0.0;
    final service = UDPGlobalSendService(
      onProgress: (value) {
        countriesSent = value;
        onProgress({
          'progress': value,
          'total': requestedCountries?.length ?? 0,
          'message': 'UDP 已发送至 $value 个国家/地区',
        });
      },
      onDataSent: (value) {
        bytesSentMb = value;
      },
      onStopped: () {},
      onLog: (message) {
        logs.add(message);
        if (logs.length > 100) logs.removeAt(0);
        onProgress({
          'progress': countriesSent,
          'total': requestedCountries?.length ?? 0,
          'message': message,
        });
      },
    );
    if (!await service.initialize()) {
      return {
        'handled': true,
        'ok': false,
        'capability': 'network.send',
        'channel': 'udp',
        'error': 'UDP 全球发送服务初始化失败',
        'logs': logs,
      };
    }
    await service.startSending(
      files: [
        PlatformFile(name: '$taskId.txt', size: bytes.length, bytes: bytes),
      ],
      isLoop: false,
      countryCodes: requestedCountries,
    );
    return {
      'handled': true,
      'ok': true,
      'capability': 'network.send',
      'channel': 'udp',
      'countriesSent': countriesSent,
      'dataSentMb': bytesSentMb,
      'logs': logs,
    };
  }

  Future<Map<String, dynamic>> _sendUdpDatagrams(
    Map<String, dynamic> params,
    MiniAppCapabilityProgress onProgress,
  ) async {
    final rawTargets = params['targets'];
    if (rawTargets is! List || rawTargets.isEmpty) {
      return {
        'handled': true,
        'ok': false,
        'capability': 'network.udp.send',
        'error': 'targets 必须包含 host/port',
      };
    }
    final payload = utf8.encode(params['payload']?.toString() ?? '');
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    var sent = 0;
    final failures = <Map<String, dynamic>>[];
    try {
      for (final rawTarget in rawTargets) {
        if (rawTarget is! Map) continue;
        final target = Map<String, dynamic>.from(rawTarget);
        final host = target['host']?.toString() ?? '';
        final port = target['port'] is int
            ? target['port'] as int
            : int.tryParse(target['port']?.toString() ?? '');
        if (host.isEmpty || port == null || port < 1 || port > 65535) {
          failures.add({'target': target, 'error': '无效的 host/port'});
          continue;
        }
        try {
          final addresses = await InternetAddress.lookup(host);
          if (addresses.isEmpty) throw const SocketException('DNS 无结果');
          final count = socket.send(payload, addresses.first, port);
          if (count != payload.length) {
            throw SocketException('只发送 $count/${payload.length} 字节');
          }
          sent += 1;
          onProgress({
            'progress': sent,
            'total': rawTargets.length,
            'message': 'UDP 已发送至 $host:$port',
          });
        } catch (error) {
          failures.add({'target': target, 'error': error.toString()});
        }
      }
    } finally {
      socket.close();
    }
    return {
      'handled': true,
      'ok': failures.isEmpty,
      'capability': 'network.udp.send',
      'channel': 'udp',
      'sentTargets': sent,
      'failedTargets': failures,
    };
  }
}
