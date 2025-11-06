import 'package:flutter/foundation.dart';

class ErrorHandler {
  static void handleError(String context, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('[$context] 错误: $error');
    if (stackTrace != null && kDebugMode) {
      debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  static void logInfo(String context, String message) {
    debugPrint('[$context] $message');
  }

  static void logWarning(String context, String message) {
    debugPrint('[$context] 警告: $message');
  }
}
