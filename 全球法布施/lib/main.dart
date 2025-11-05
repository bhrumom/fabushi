import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'models/file_transfer_model.dart';
import 'models/settings_model.dart';
import 'models/auth_model.dart';
import 'models/country_sending_model.dart';
import 'models/leaderboard_model.dart';
import 'services/app_initializer.dart';
import 'widgets/app_wrapper.dart';
import 'screens/login_screen.dart';
import 'core/video_feed_di/video_feed_injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面平台设置窗口固定最大化
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.setMaximizable(false);
    await windowManager.setResizable(false);
    await windowManager.maximize();
  }

  // 尝试初始化Firebase，如果失败则继续运行
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase初始化成功');
  } catch (e) {
    debugPrint('⚠️ Firebase初始化失败（可选功能）: $e');
  }

  // Web平台使用HTML渲染器
  if (kIsWeb) {
    debugPrint('使用HTML渲染器加快网页加载速度');
  }

  // 异步初始化，不阻塞启动
  AppInitializer.initialize().catchError((e) => debugPrint('初始化失败: $e'));

  // 初始化 Video Feed 依赖
  setupVideoFeedDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthModel()),
        ChangeNotifierProvider(create: (context) => FileTransferModel()),
        ChangeNotifierProvider(create: (context) => SettingsModel()),
        ChangeNotifierProvider(create: (context) => CountrySendingModel()),
        ChangeNotifierProvider(create: (context) => LeaderboardModel()),
      ],
      child: MaterialApp(
        title: '全球法布施',
        debugShowCheckedModeBanner: false,
        routes: {'/login': (context) => const LoginScreen()},
        theme: FlexThemeData.light(
          scheme: FlexScheme.deepPurple,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 7,
          subThemesData: const FlexSubThemesData(
            blendOnLevel: 10,
            useFlutterDefaults: true,
          ),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
          useMaterial3: true,
          fontFamily: 'NotoSansSC',
        ),
        darkTheme: FlexThemeData.dark(
          scheme: FlexScheme.deepPurple,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 13,
          subThemesData: const FlexSubThemesData(
            blendOnLevel: 20,
            useFlutterDefaults: true,
          ),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
          useMaterial3: true,
          fontFamily: 'NotoSansSC',
        ),
        themeMode: ThemeMode.light,
        home: const AppWrapper(),
      ),
    );
  }
}
