import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/video_feed_di/video_feed_injector.dart';
import '../firebase_options.dart';
import '../services/app_initializer.dart';
import '../services/error_report_service.dart';

Future<void> startDeferredWebServices() async {
  unawaited(ErrorReportService.instance.initializeGlobalHandlers());

  Future<void>.delayed(const Duration(milliseconds: 800), () async {
    try {
      await AppInitializer.initialize();
      debugPrint('Web AppInitializer initialized after first paint');
    } catch (error, stackTrace) {
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'web_background_initializer',
        source: 'web_deferred_startup',
      );
    }
  });

  Future<void>.delayed(const Duration(seconds: 3), () async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 6));
        debugPrint('Web Firebase initialized after first paint');
      }
    } catch (error, stackTrace) {
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'firebase_initialize_web_deferred',
        source: 'web_deferred_startup',
      );
    }
  });

  Future<void>.delayed(const Duration(seconds: 4), () async {
    try {
      setupVideoFeedDependencies();
      debugPrint('Web Video Feed DI registered after first paint');
    } catch (error, stackTrace) {
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'video_feed_di_web_deferred',
        source: 'web_deferred_startup',
      );
    }
  });
}
