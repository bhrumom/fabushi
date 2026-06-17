import 'dart:convert';

import 'package:flutter/foundation.dart';

class DiagnosticLogService {
  DiagnosticLogService._();

  static final DiagnosticLogService instance = DiagnosticLogService._();

  Future<void> log(
    String category,
    String message, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) async {
    debugPrint(
      '[DachengDiag][$category] $message${data.isEmpty ? '' : ' ${jsonEncode(data)}'}',
    );
    if (error != null) {
      debugPrint('[DachengDiag][$category] error=$error');
    }
    if (stackTrace != null) {
      debugPrint('[DachengDiag][$category] stack=$stackTrace');
    }
  }

  Future<String?> logFilePath() async => null;

  Future<String> tail({int maxLines = 300}) async => '当前平台没有持久化诊断日志文件。';
}
