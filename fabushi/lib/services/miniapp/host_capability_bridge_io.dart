import 'dart:async';
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
    if (capability.startsWith('desktop.chatgpt-approvals.')) {
      return _runChatGptApprovalCapability(capability, params, onProgress);
    }
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

  Future<Map<String, dynamic>> _runChatGptApprovalCapability(
    String capability,
    Map<String, dynamic> params,
    MiniAppCapabilityProgress onProgress,
  ) async {
    if (!Platform.isMacOS) {
      return {
        'handled': true,
        'ok': false,
        'capability': capability,
        'error': 'ChatGPT 自动确认当前仅支持 macOS 桌面端',
      };
    }
    final runtime = await _findChatGptApprovalRuntime();
    if (runtime == null) {
      return {
        'handled': true,
        'ok': false,
        'capability': capability,
        'error': '未找到 ChatGPT 自动确认原生运行时，请先安装或更新小程序',
      };
    }
    final suffix = capability.substring('desktop.chatgpt-approvals.'.length);
    final arguments = switch (suffix) {
      'start' => ['start', jsonEncode(params)],
      'stop' => const ['stop'],
      'status' => const ['status'],
      'scan-once' => ['scan', jsonEncode(params)],
      'relaunch-and-confirm' => ['relaunch_and_confirm', jsonEncode(params)],
      'audit' => ['audit', '${params['limit'] ?? 20}'],
      'diagnose' => const ['diagnose'],
      'send-and-watch' => ['send_and_watch', jsonEncode(params)],
      'add-connector' => ['add_connector', jsonEncode(params)],
      'get-reply' => ['get_reply', jsonEncode(params)],
      'chat-status' => ['chat_status', jsonEncode(params)],
      'queue-enqueue' => ['queue_enqueue', jsonEncode(params)],
      'queue-start' => ['queue_start', jsonEncode(params)],
      'queue-status' => const ['queue_status'],
      'queue-wait-review' => ['queue_wait_review', jsonEncode(params)],
      'queue-review' => ['queue_review', jsonEncode(params)],
      'queue-pause' => const ['queue_pause'],
      'queue-resume' => const ['queue_resume'],
      'queue-retry' => ['queue_retry', jsonEncode(params)],
      'queue-cancel' => ['queue_cancel', jsonEncode(params)],
      _ => const <String>[],
    };
    if (arguments.isEmpty) {
      return {
        'handled': false,
        'capability': capability,
        'reason': '未知的 ChatGPT 自动确认能力',
      };
    }
    if (suffix == 'send-and-watch') {
      return _runChatGptSendAndWatch(
        runtime,
        arguments,
        params,
        capability,
        onProgress,
      );
    }
    final result = await Process.run(runtime, arguments, runInShell: false);
    return _nativeChatGptResult(
      capability,
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  }

  Future<Map<String, dynamic>> _runChatGptSendAndWatch(
    String runtime,
    List<String> arguments,
    Map<String, dynamic> params,
    String capability,
    MiniAppCapabilityProgress onProgress,
  ) async {
    final process = await Process.start(runtime, arguments, runInShell: false);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final pollIntervalMs = ((params['pollIntervalMs'] as num?)?.toInt() ?? 500)
        .clamp(200, 5000);
    var polling = false;
    var finished = false;
    var lastSignature = '';

    Future<void> pollReply() async {
      if (polling || finished) return;
      polling = true;
      try {
        final polled = await Process.run(runtime, [
          'get_reply',
          jsonEncode({'chatUrl': params['chatUrl']}),
        ], runInShell: false);
        final reply = _decodeLastJson(polled.stdout.toString());
        if (polled.exitCode != 0 || reply == null || reply['ok'] != true) {
          return;
        }
        final signature = jsonEncode([
          reply['messageCount'],
          reply['userMessageCount'],
          reply['charCount'],
          reply['streaming'],
          reply['pending'],
          reply['done'],
        ]);
        if (signature == lastSignature || finished) return;
        lastSignature = signature;
        final done = reply['done'] == true;
        final pending = reply['pending'] == true;
        onProgress({
          'progress': done ? 1 : 0,
          'total': 1,
          'message': done
              ? 'ChatGPT 回复完成'
              : pending
              ? 'ChatGPT 正在处理，等待新回复'
              : '正在实时接收 ChatGPT 回复（${reply['charCount'] ?? 0} 字）',
          'reply': reply,
        });
      } finally {
        polling = false;
      }
    }

    final timer = Timer.periodic(
      Duration(milliseconds: pollIntervalMs),
      (_) => unawaited(pollReply()),
    );
    unawaited(pollReply());
    final exitCode = await process.exitCode;
    finished = true;
    timer.cancel();
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    final result = _nativeChatGptResult(capability, exitCode, stdout, stderr);
    final finalReply = result['reply'];
    if (finalReply is Map) {
      onProgress({
        'progress': finalReply['done'] == true ? 1 : 0,
        'total': 1,
        'message': finalReply['done'] == true
            ? 'ChatGPT 回复完成'
            : 'ChatGPT 回复尚未完成',
        'reply': Map<String, dynamic>.from(finalReply),
      });
    }
    return result;
  }

  Map<String, dynamic> _nativeChatGptResult(
    String capability,
    int exitCode,
    String stdout,
    String stderr,
  ) {
    final decoded = _decodeLastJson(stdout);
    if (decoded == null) {
      return {
        'handled': true,
        'ok': false,
        'capability': capability,
        'error': stderr.trim().isNotEmpty
            ? stderr.trim()
            : 'ChatGPT 自动确认原生运行时没有返回有效结果',
        'exitCode': exitCode,
      };
    }
    return {
      'handled': true,
      'capability': capability,
      ...decoded,
      if (exitCode != 0) 'exitCode': exitCode,
    };
  }

  Map<String, dynamic>? _decodeLastJson(String value) {
    final lines = const LineSplitter()
        .convert(value)
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    for (final line in lines.reversed) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Native diagnostics can precede the final JSON line.
      }
    }
    return null;
  }

  Future<String?> _findChatGptApprovalRuntime() async {
    final override = Platform.environment['CHATGPT_AUTO_CONFIRM_NATIVE'];
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final userDirectory = Platform.environment['HOME'];
    final candidates = <String>[
      if (override != null && override.trim().isNotEmpty) override.trim(),
      '${Directory.current.path}/.agents/plugins/plugins/chatgpt-auto-confirm/runtime/macos/chatgpt-auto-confirm',
      '$executableDirectory/../Resources/plugins/chatgpt-auto-confirm/runtime/macos/chatgpt-auto-confirm',
      '$executableDirectory/../Frameworks/App.framework/Resources/flutter_assets/.agents/plugins/plugins/chatgpt-auto-confirm/runtime/macos/chatgpt-auto-confirm',
      if (userDirectory != null && userDirectory.isNotEmpty)
        '$userDirectory/Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm/runtime/macos/chatgpt-auto-confirm',
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    return null;
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
