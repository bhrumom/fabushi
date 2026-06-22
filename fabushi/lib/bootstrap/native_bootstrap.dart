import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
import '../core/video_feed_di/video_feed_injector.dart';
import '../firebase_options.dart';
import '../services/app_initializer.dart';
import '../services/error_report_service.dart';
import '../services/openclaw/openclaw_home_chat_e2e.dart';
import 'native_app.dart';

Future<void> bootstrapApplication() async {
  debugPrint('🚀 [native] App starting...');
  await ErrorReportService.instance.initializeGlobalHandlers();

  await runZonedGuarded(
    () async {
      debugPrint('🚀 [native] setupDependencies() begin');
      setupDependencies();
      debugPrint('🚀 [native] setupDependencies() done');

      if (kDebugMode) {
        AppConfig.printConfigInfo();
      }

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.ensureInitialized();
        await windowManager.setMaximizable(true);
        await windowManager.setResizable(true);
        await windowManager.maximize();
      }

      try {
        if (Firebase.apps.isEmpty) {
          debugPrint('🚀 [native] Firebase.initializeApp() begin');
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 5));
          debugPrint('✅ [native] Firebase初始化成功');
        } else {
          debugPrint('✅ [native] Firebase已初始化，跳过');
        }
      } catch (error, stackTrace) {
        debugPrint('⚠️ [native] Firebase初始化失败: $error');
        unawaited(
          ErrorReportService.instance.recordError(
            error,
            stackTrace: stackTrace,
            stage: 'firebase_initialize',
            source: 'native_bootstrap',
            extra: {'platform': 'mobile_or_desktop'},
          ),
        );
      }

      Future<void>.delayed(const Duration(milliseconds: 100), () async {
        debugPrint('🚀 [native] AppInitializer.initialize() begin');
        try {
          await AppInitializer.initialize();
          debugPrint('🚀 [native] AppInitializer.initialize() done');
        } catch (error, stackTrace) {
          debugPrint('初始化失败: $error');
          await ErrorReportService.instance.recordError(
            error,
            stackTrace: stackTrace,
            stage: 'main_delayed_initializer',
            source: 'native_bootstrap',
          );
        }
      });

      debugPrint('🚀 [native] setupVideoFeedDependencies() begin');
      setupVideoFeedDependencies();
      debugPrint('🚀 [native] setupVideoFeedDependencies() done');

      debugPrint('🚀 [native] runApp(NativeApp) begin');
      runApp(const NativeApp());
      await maybeRunOpenClawHomeChatE2E();
    },
    (error, stackTrace) {
      unawaited(
        ErrorReportService.instance.recordError(
          error,
          stackTrace: stackTrace,
          stage: 'run_zoned_guarded',
          source: 'native_bootstrap',
          fatal: true,
        ),
      );
    },
  );
}
