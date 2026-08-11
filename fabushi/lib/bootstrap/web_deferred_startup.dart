import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_initializer.dart';
import '../services/error_report_service.dart';

Future<void> startDeferredWebServices() async {
  unawaited(ErrorReportService.instance.initializeGlobalHandlers());

  Future<void>.delayed(const Duration(milliseconds: 800), () async {
    try {
      await AppInitializer.initialize();
      debugPrint('Web platform core initialized after first paint');
    } catch (error, stackTrace) {
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'web_background_initializer',
        source: 'web_deferred_startup',
      );
    }
  });
}
