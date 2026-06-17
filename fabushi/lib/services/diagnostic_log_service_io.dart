import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DiagnosticLogService {
  DiagnosticLogService._();

  static final DiagnosticLogService instance = DiagnosticLogService._();

  Future<void> _writeChain = Future<void>.value();

  Future<void> log(
    String category,
    String message, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = <String, Object?>{
      'ts': DateTime.now().toIso8601String(),
      'category': category,
      'message': message,
      if (data.isNotEmpty) 'data': _sanitize(data),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': _truncate(stackTrace.toString()),
    };
    final line = jsonEncode(entry);
    debugPrint(
      '[DachengDiag][$category] $message${data.isEmpty ? '' : ' ${jsonEncode(_sanitize(data))}'}',
    );

    _writeChain = _writeChain
        .catchError((_) {})
        .then((_) async {
          final file = await _logFile();
          await file.parent.create(recursive: true);
          await file.writeAsString('$line\n', mode: FileMode.append);
        })
        .catchError((error) {
          debugPrint('[DachengDiag] write failed: $error');
        });
    return _writeChain;
  }

  Future<String?> logFilePath() async => (await _logFile()).path;

  Future<String> tail({int maxLines = 300}) async {
    final file = await _logFile();
    if (!await file.exists()) {
      return '诊断日志不存在: ${file.path}';
    }
    final lines = await file.readAsLines();
    final start = lines.length > maxLines ? lines.length - maxLines : 0;
    return lines.skip(start).join('\n');
  }

  Future<File> _logFile() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, 'diagnostics', 'dacheng-diagnostics.log'));
  }

  Object? _sanitize(Object? value, [String key = '']) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('token') ||
        lowerKey.contains('password') ||
        lowerKey.contains('authorization') ||
        lowerKey.contains('auth')) {
      return '<redacted>';
    }
    if (value is Map) {
      return value.map(
        (mapKey, mapValue) =>
            MapEntry(mapKey.toString(), _sanitize(mapValue, mapKey.toString())),
      );
    }
    if (value is Iterable) {
      return value.map((item) => _sanitize(item)).toList();
    }
    if (value is String) return _truncate(value);
    return value;
  }

  String _truncate(String value, {int max = 2000}) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}...<truncated ${value.length - max} chars>';
  }
}
