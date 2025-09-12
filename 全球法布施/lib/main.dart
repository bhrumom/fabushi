import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/file_transfer_model.dart';
import 'models/settings_model.dart';
import 'models/auth_model.dart';
import 'models/country_sending_model.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
      ],
      child: MaterialApp(
        title: '全球法布施',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // 添加更现代的主题配置
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF667eea),
            brightness: Brightness.light,
          ),
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
        home: const HomeScreen(),
      ),
    );
  }
}