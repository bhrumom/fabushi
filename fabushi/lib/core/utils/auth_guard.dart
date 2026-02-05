import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/auth_model.dart';

class AuthGuard {
  /// 检查是否登录，如果未登录则跳转到登录页面
  /// 返回 true 表示已登录或登录成功，返回 false 表示未登录且取消登录
  static Future<bool> check(BuildContext context) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    
    if (authModel.isLoggedIn) {
      return true;
    }
    
    // 未登录，跳转到登录页面
    // 这里的 '/login' 已经在 main.dart 中注册为 DouyinLoginScreen
    final result = await Navigator.pushNamed(context, '/login');
    
    return result == true;
  }

  /// 抖音风格的登录提示：如果是未登录用户执行需要同步的操作，直接弹出登录
  static Future<void> runWithGuard(BuildContext context, VoidCallback action) async {
    final hasAuth = await check(context);
    if (hasAuth) {
      action();
    }
  }
}
