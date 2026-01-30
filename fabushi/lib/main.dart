import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
// Firebase removed for Windows compatibility
// import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'dart:io';
// import 'firebase_options.dart';
import 'core/di/injection.dart';
import 'core/config/app_config.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化依赖注入
  setupDependencies();

  // 打印配置信息（仅调试模式）
  if (kDebugMode) {
    AppConfig.printConfigInfo();
  }

  // 桌面平台设置（Web跳过）
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    debugPrint('🔧 跳过 WindowManager 初始化 (调试中)');
    // await windowManager.ensureInitialized();
    // await windowManager.setMaximizable(false);
    // await windowManager.setResizable(false);
    // await windowManager.maximize();
  }

  // Firebase removed for Windows compatibility - all Firebase code commented out
  debugPrint('🔧 Firebase 已移除 (Windows兼容性)');

  // 延迟异步初始化，避免阻塞启动
  Future.delayed(const Duration(milliseconds: 100), () {
    AppInitializer.initialize().catchError((e) => debugPrint('初始化失败: $e'));
  });

  // 🚀 立即初始化Video Feed依赖（不阻塞）
  setupVideoFeedDependencies();
  
  // 🚀 后台预加载法流内容，实现秒加载
  Future.microtask(() async {
    try {
      final textService = videoFeedGetIt<CloudflareTextService>();
      await textService.preloadOnAppStart();
    } catch (e) {
      debugPrint('⚠️ 预加载启动失败: $e');
    }
  });

  // 🚀 初始化语义NLP服务（轻量级，不阻塞）
  // 提前初始化正则状态机和TFLite模型（如有）
  // Future.microtask(() async {
  //   try {
  //     await SemanticNlpService.instance.initialize();
  //     debugPrint('✅ 语义NLP服务初始化完成');
  //   } catch (e) {
  //     debugPrint('⚠️ 语义NLP服务初始化失败: $e');
  //   }
  // });

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
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        routes: {'/login': (_) => const DouyinLoginScreen()},
        theme: AppTheme.lightTheme, // Though we prefer dark for space theme
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Enforce Dark/Space theme
        home: const AppWrapper(),
      ),
    );
  }
}
