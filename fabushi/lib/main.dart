import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config/app_config.dart';
import 'core/design_system/app_theme.dart';
import 'core/di/injection.dart';
import 'core/video_feed_di/video_feed_injector.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'models/auth_model.dart';
import 'models/country_sending_model.dart';
import 'models/file_transfer_model.dart';
import 'models/leaderboard_model.dart';
import 'models/settings_model.dart';
import 'providers/tts_mute_notifier.dart';
import 'providers/video_feed_visibility_notifier.dart';
import 'screens/douyin_login_screen.dart';
import 'services/app_initializer.dart';
import 'services/error_report_service.dart';
import 'widgets/app_wrapper.dart';

Future<void> main() async {
  debugPrint(
    '🚀 [main] App starting... WidgetsFlutterBinding.ensureInitialized()',
  );
  WidgetsFlutterBinding.ensureInitialized();
  await ErrorReportService.instance.initializeGlobalHandlers();

  await runZonedGuarded(() async {
    // 初始化依赖注入
    debugPrint('🚀 [main] setupDependencies() begin');
    setupDependencies();
    debugPrint('🚀 [main] setupDependencies() done');

    // 打印配置信息（仅调试模式）
    if (kDebugMode) {
      AppConfig.printConfigInfo();
    }

    // 桌面平台设置（Web跳过）
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.ensureInitialized();
      await windowManager.setMaximizable(false);
      await windowManager.setResizable(false);
      await windowManager.maximize();
    }

    // Firebase初始化（Web平台延迟初始化以优化首屏速度）
    if (!kIsWeb) {
      try {
        // 检查是否已初始化，避免重复初始化
        if (Firebase.apps.isEmpty) {
          debugPrint('🚀 [main] Firebase.initializeApp() begin');
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠️ [main] Firebase初始化超时 (5s)');
              return null as dynamic;
            },
          );
          debugPrint('✅ [main] Firebase初始化成功');
        } else {
          debugPrint('✅ [main] Firebase已初始化，跳过');
        }
      } catch (error, stackTrace) {
        debugPrint('⚠️ [main] Firebase初始化失败: $error');
        unawaited(
          ErrorReportService.instance.recordError(
            error,
            stackTrace: stackTrace,
            stage: 'firebase_initialize',
            source: 'main',
            extra: {'platform': 'mobile_or_desktop'},
          ),
        );
      }
    } else {
      // Web平台：延迟Firebase初始化到用户交互后
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
            debugPrint('✅ Firebase初始化成功（Web延迟）');
          }
        } catch (error, stackTrace) {
          debugPrint('⚠️ Firebase初始化失败: $error');
          unawaited(
            ErrorReportService.instance.recordError(
              error,
              stackTrace: stackTrace,
              stage: 'firebase_initialize_web_delayed',
              source: 'main',
            ),
          );
        }
      });
    }

    // 延迟异步初始化，避免阻塞启动
    Future.delayed(const Duration(milliseconds: 100), () async {
      debugPrint('🚀 [main] AppInitializer.initialize() begin');
      try {
        await AppInitializer.initialize();
        debugPrint('🚀 [main] AppInitializer.initialize() done');
      } catch (error, stackTrace) {
        debugPrint('初始化失败: $error');
        await ErrorReportService.instance.recordError(
          error,
          stackTrace: stackTrace,
          stage: 'main_delayed_initializer',
          source: 'main',
        );
      }
    });

    // 🚀 立即初始化Video Feed依赖（不阻塞）
    debugPrint('🚀 [main] setupVideoFeedDependencies() begin');
    setupVideoFeedDependencies();
    debugPrint('🚀 [main] setupVideoFeedDependencies() done');

    debugPrint('🚀 [main] runApp(MyApp) begin');
    runApp(const MyApp());
  }, (error, stackTrace) {
    unawaited(
      ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'run_zoned_guarded',
        source: 'main',
        fatal: true,
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => FileTransferModel()),
        ChangeNotifierProvider(create: (_) => SettingsModel()),
        ChangeNotifierProvider(create: (_) => CountrySendingModel()),
        ChangeNotifierProvider(create: (_) => LeaderboardModel()),
        ChangeNotifierProvider(create: (_) => VideoFeedVisibilityNotifier()),
        ChangeNotifierProvider(create: (_) => TtsMuteNotifier()..initialize()),
      ],
      child: Consumer<SettingsModel>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConfig.appName,
            onGenerateTitle: (context) => context.l10n.appName,
            debugShowCheckedModeBanner: false,
            locale: settings.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback:
                AppLocalizations.localeListResolutionCallback,
            routes: {'/login': (_) => const DouyinLoginScreen()},
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}
