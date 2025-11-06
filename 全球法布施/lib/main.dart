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

  // 初始化依赖注入
  setupDependencies();

  // 打印配置信息
  AppConfig.printConfigInfo();

  // 桌面平台设置
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.setMaximizable(false);
    await windowManager.setResizable(false);
    await windowManager.maximize();
  }

  // Firebase初始化
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase初始化成功');
  } catch (e) {
    debugPrint('⚠️ Firebase初始化失败: $e');
  }

  // 异步初始化
  AppInitializer.initialize().catchError((e) => debugPrint('初始化失败: $e'));

  // Video Feed依赖
  setupVideoFeedDependencies();

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
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        routes: {'/login': (_) => const LoginScreen()},
        theme: FlexThemeData.light(
          scheme: FlexScheme.deepPurple,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 7,
          subThemesData: const FlexSubThemesData(blendOnLevel: 10, useFlutterDefaults: true),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
          useMaterial3: true,
          fontFamily: 'NotoSansSC',
        ),
        darkTheme: FlexThemeData.dark(
          scheme: FlexScheme.deepPurple,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 13,
          subThemesData: const FlexSubThemesData(blendOnLevel: 20, useFlutterDefaults: true),
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
