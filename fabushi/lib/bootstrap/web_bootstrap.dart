import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
import '../core/video_feed_di/video_feed_injector.dart';
import '../firebase_options.dart';
import '../services/app_initializer.dart';
import '../services/error_report_service.dart';
import 'app_bootstrap.dart' hide bootstrapApplication;

Future<void> bootstrapApplication() async {
  debugPrint('⚡ [web] App starting with lean first-paint path...');

  await runZonedGuarded(() async {
    setupDependencies();

    if (kDebugMode) {
      AppConfig.printConfigInfo();
    }

    runApp(const MyApp());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleWebBackgroundStartup();
    });
  }, (error, stackTrace) {
    unawaited(
      ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'run_zoned_guarded_web',
        source: 'web_bootstrap',
        fatal: true,
      ),
    );
  });
}

void _scheduleWebBackgroundStartup() {
  unawaited(ErrorReportService.instance.initializeGlobalHandlers());

  Future<void>.delayed(const Duration(milliseconds: 1200), () async {
    try {
      await AppInitializer.initialize();
      debugPrint('✅ [web] AppInitializer initialized in background');
    } catch (error, stackTrace) {
      debugPrint('⚠️ [web] AppInitializer background init failed: $error');
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'web_background_initializer',
        source: 'web_bootstrap',
      );
    }
  });

  Future<void>.delayed(const Duration(seconds: 3), () async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 6));
        debugPrint('✅ [web] Firebase initialized after first paint');
      }
    } catch (error, stackTrace) {
      debugPrint('⚠️ [web] Firebase deferred init failed: $error');
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'firebase_initialize_web_deferred',
        source: 'web_bootstrap',
      );
    }
  });

  Future<void>.delayed(const Duration(seconds: 4), () async {
    try {
      setupVideoFeedDependencies();
      debugPrint('✅ [web] Video Feed dependencies registered after first paint');
    } catch (error, stackTrace) {
      debugPrint('⚠️ [web] Video Feed deferred DI failed: $error');
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'video_feed_di_web_deferred',
        source: 'web_bootstrap',
      );
    }
  });
}
