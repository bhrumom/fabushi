import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'core/di/injection.dart';
import 'core/config/app_config.dart';
import 'l10n/app_localizations.dart';
import 'models/file_transfer_model.dart';
import 'models/settings_model.dart';
import 'models/auth_model.dart';
import 'models/country_sending_model.dart';
import 'models/leaderboard_model.dart';
import 'services/app_initializer.dart';
import 'widgets/app_wrapper.dart';
import 'screens/douyin_login_screen.dart';
import 'core/video_feed_di/video_feed_injector.dart';
import 'core/design_system/app_theme.dart';
import 'providers/video_feed_visibility_notifier.dart';
import 'providers/tts_mute_notifier.dart';
import 'services/cloudflare_text_service.dart';
import 'services/semantic_nlp_service.dart';
import 'services/app_settings.dart';

void main() async {
  debugPrint('🚀 [main] App starting... WidgetsFlutterBinding.ensureInitialized()');
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化依赖注入
  debugPrint('🚀 [main] setupDependencies() begin');
  setupDependencies();
  debugPrint('🚀 [main] setupDependencies() done');

  // 打印配置信息（仅调试模式）
  if (kDebugMode) {
    AppConfig.printConfigInfo();
  }

  // 桌面平台设置（Web跳过）
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
            .timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint('⚠️ [main] Firebase初始化超时 (5s)');
          return null as dynamic;
        });
        debugPrint('✅ [main] Firebase初始化成功');
      } else {
        debugPrint('✅ [main] Firebase已初始化，跳过');
      }
    } catch (e) {
      debugPrint('⚠️ [main] Firebase初始化失败: $e');
    }
  } else {
    // Web平台：延迟Firebase初始化到用户交互后
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
          debugPrint('✅ Firebase初始化成功（Web延迟）');
        }
      } catch (e) {
        debugPrint('⚠️ Firebase初始化失败: $e');
      }
    });
  }

  // 延迟异步初始化，避免阻塞启动
  Future.delayed(const Duration(milliseconds: 100), () {
    debugPrint('🚀 [main] AppInitializer.initialize() begin');
    AppInitializer.initialize().then((_) {
      debugPrint('🚀 [main] AppInitializer.initialize() done');
    }).catchError((e) => debugPrint('初始化失败: $e'));
  });

  // 🚀 立即初始化Video Feed依赖（不阻塞）
  debugPrint('🚀 [main] setupVideoFeedDependencies() begin');
  setupVideoFeedDependencies();
  debugPrint('🚀 [main] setupVideoFeedDependencies() done');
  
  // 注释掉启动时的法流数据预加载，避免因自动请求引来网络排查
  /*
  Future.microtask(() async {
    try {
      final textService = videoFeedGetIt<CloudflareTextService>();
      await textService.preloadOnAppStart();
    } catch (e) {
      debugPrint('⚠️ 预加载启动失败: $e');
    }
  });
  */

  // 语义 NLP 服务、Firebase 等重型服务的详细初始化已迁移至 AppInitializer 统一管理
  // 旨在实现启动阶段的削峰填谷，避免内存崩溃

  debugPrint('🚀 [main] runApp(MyApp) begin');
  runApp(const MyApp());
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
            theme: AppTheme.lightTheme, // Though we prefer dark for space theme
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark, // Enforce Dark/Space theme
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}
