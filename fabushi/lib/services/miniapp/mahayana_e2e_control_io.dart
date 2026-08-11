import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../mahayana_sdk.dart';
import 'mahayana_marketplace_service.dart';
import 'mahayana_workspace.dart';

const bool _e2eControlEnabled = bool.fromEnvironment(
  'FABUSHI_E2E_CONTROL',
  defaultValue: false,
);
const String _protocol = 'fabushi.e2e.control.v1';

/// Starts a filesystem-backed, debug-only control channel for deterministic
/// E2E state queries. It is intentionally not a socket server and is disabled
/// unless the test build explicitly opts in with a Dart define.
///
/// Methods delegate to production services. In particular,
/// `marketplace.install` uses [MahayanaMarketplaceService.install] and cannot
/// write arbitrary paths supplied by the test harness.
Future<void> startMahayanaE2eControlIfEnabled() async {
  if (!kDebugMode || !_e2eControlEnabled) return;
  await _MahayanaE2eControl.instance.start();
}

class _MahayanaE2eControl {
  _MahayanaE2eControl._();

  static final _MahayanaE2eControl instance = _MahayanaE2eControl._();

  Timer? _timer;
  Directory? _directory;
  bool _processing = false;

  Future<void> start() async {
    if (_timer != null) return;
    final paths = await prepareMahayanaRuntimePaths();
    final dataDir = paths['dataDir']?.toString().trim() ?? '';
    if (dataDir.isEmpty) return;
    final directory = Directory(p.join(dataDir, 'e2e-control'));
    await directory.create(recursive: true);
    _directory = directory;
    await _writeAtomic(
      File(p.join(directory.path, 'ready.json')),
      <String, dynamic>{'protocol': _protocol, 'ready': true, 'pid': pid},
    );
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_poll()),
    );
  }

  Future<void> _poll() async {
    final directory = _directory;
    if (_processing || directory == null) return;
    final requestFile = File(p.join(directory.path, 'request.json'));
    if (!await requestFile.exists()) return;
    _processing = true;
    try {
      final raw = await requestFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('request must be a JSON object');
      }
      final request = Map<String, dynamic>.from(decoded);
      final id = _safeId(request['id']?.toString() ?? '');
      final responseFile = File(p.join(directory.path, 'response-$id.json'));
      Map<String, dynamic> response;
      try {
        if (request['protocol'] != _protocol) {
          throw const FormatException('unsupported E2E control protocol');
        }
        final method = request['method']?.toString().trim() ?? '';
        final params = request['params'] is Map
            ? Map<String, dynamic>.from(request['params'] as Map)
            : <String, dynamic>{};
        response = <String, dynamic>{
          'protocol': _protocol,
          'id': id,
          'ok': true,
          'result': await _execute(method, params),
        };
      } catch (error) {
        response = <String, dynamic>{
          'protocol': _protocol,
          'id': id,
          'ok': false,
          'error': error.toString(),
        };
      }
      await _writeAtomic(responseFile, response);
    } catch (error) {
      final fallback = File(p.join(directory.path, 'response-invalid.json'));
      await _writeAtomic(fallback, <String, dynamic>{
        'protocol': _protocol,
        'id': 'invalid',
        'ok': false,
        'error': error.toString(),
      });
    } finally {
      try {
        await requestFile.delete();
      } catch (_) {
        // A stale request is harmless; the next poll will overwrite its
        // response with the same request id.
      }
      _processing = false;
    }
  }

  Future<Map<String, dynamic>> _execute(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'ping':
        return const <String, dynamic>{'protocol': _protocol, 'enabled': true};
      case 'auth.status':
        return MahayanaSdk.instance.execute(const {
          '@type': 'mahayana.auth.status',
        });
      case 'marketplace.search':
        return MahayanaMarketplaceService.instance.search(
          _requiredString(params, 'query'),
        );
      case 'marketplace.install':
        return MahayanaMarketplaceService.instance.install(
          _requiredString(params, 'pluginId'),
          version: _optionalString(params, 'version'),
        );
      case 'marketplace.inspect':
        return MahayanaMarketplaceService.instance.inspect(
          _requiredString(params, 'pluginId'),
        );
      case 'runtime.status':
        return MahayanaSdk.instance.execute(const {
          '@type': 'mahayana.runtime.status',
        });
      default:
        throw ArgumentError.value(
          method,
          'method',
          'unsupported E2E control method',
        );
    }
  }

  String _requiredString(Map<String, dynamic> params, String name) {
    final value = params[name]?.toString().trim() ?? '';
    if (value.isEmpty) throw ArgumentError('$name is required');
    return value;
  }

  String? _optionalString(Map<String, dynamic> params, String name) {
    final value = params[name]?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String _safeId(String value) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(value)) {
      throw const FormatException('request id is invalid');
    }
    return value;
  }

  Future<void> _writeAtomic(
    File destination,
    Map<String, dynamic> value,
  ) async {
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
      flush: true,
    );
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }
}
