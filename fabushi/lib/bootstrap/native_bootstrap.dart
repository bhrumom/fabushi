import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
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
