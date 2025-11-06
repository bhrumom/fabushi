import 'package:flutter/material.dart';

/// 应用路由配置
class AppRouter {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String profile = '/profile';
  static const String membership = '/membership';
  static const String settings = '/settings';
  static const String leaderboard = '/leaderboard';
  static const String videoFeed = '/video-feed';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => Container()); // 待实现
      case login:
        return MaterialPageRoute(builder: (_) => Container()); // 待实现
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(body: Center(child: Text('页面未找到: ${settings.name}'))),
        );
    }
  }
}
