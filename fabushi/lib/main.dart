import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import 'firebase_options.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 首帧前只做纯内存、零 I/O 的依赖注册，避免白屏等待。
  setupDependencies();
  setupVideoFeedDependencies();

  if (kDebugMode) {
    scheduleMicrotask(AppConfig.printConfigInfo);
  }

  runApp(const MyApp());
  _scheduleDeferredStartupWork();
}

void _scheduleDeferredStartupWork() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 桌面窗口调整不再阻塞首帧；移动端不会进入该分支。
    unawaited(_configureDesktopWindow());

    // Firebase、后台保活、上传恢复等重型任务全部移到首帧之后。
    unawaited(_runDeferredStartupWork());
  });
}

Future<void> _configureDesktopWindow() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

  try {
    await windowManager.ensureInitialized();
    await windowManager.setMaximizable(false);
    await windowManager.setResizable(false);
    await windowManager.maximize();
  } catch (e) {
    debugPrint('⚠️ 桌面窗口初始化失败: $e');
  }
}

Future<void> _runDeferredStartupWork() async {
  await _initializeFirebaseIfNeeded();

  // 给首屏交互和首批布局留出一小段时间，再启动分批初始化。
  await Future<void>.delayed(const Duration(milliseconds: 180));

  try {
    await AppInitializer.initialize();
  } catch (e) {
    debugPrint('⚠️ 后台初始化失败: $e');
  }
}

Future<void> _initializeFirebaseIfNeeded() async {
  try {
    if (Firebase.apps.isNotEmpty) {
      debugPrint('✅ Firebase已初始化，跳过');
      return;
    }

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 4));
    debugPrint('✅ Firebase初始化成功（首帧后）');
  } on TimeoutException {
    debugPrint('⚠️ Firebase初始化超时，继续保持首屏可用');
  } catch (e) {
    debugPrint('⚠️ Firebase初始化失败: $e');
  }
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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const AppWrapper(),
      ),
    );
  }
}
