import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/file_transfer_model.dart';
import 'models/settings_model.dart';
import 'models/auth_model.dart';
import 'models/country_sending_model.dart';
import 'models/practice_model.dart';
import 'models/leaderboard_model.dart';
import 'services/app_initializer.dart';
import 'widgets/app_wrapper.dart';
import 'screens/login_screen.dart';


void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化应用
  try {
    await AppInitializer.initialize();
  } catch (e) {
    debugPrint('应用初始化失败，但继续启动: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => FileTransferModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => CountrySendingModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => PracticeModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => LeaderboardModel(),
        ),
      ],
      child: MaterialApp(
        title: '全球法布施',
        routes: {
          '/login': (context) => const LoginScreen(),
        },
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // 添加更现代的主题配置
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF667eea),
            brightness: Brightness.light,
          ),
          // 设置默认字体以支持中文字符
          fontFamily: 'NotoSansSC',
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ),
        home: const AppWrapper(),
      ),
    );
  }
}