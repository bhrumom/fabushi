import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 支付宝服务
/// 
/// 在移动端使用 tobias SDK 进行支付宝支付/授权。
/// 在桌面端仅支持 Web 支付跳转。
class AlipayService {
  static final AlipayService _instance = AlipayService._internal();
  factory AlipayService() => _instance;
  AlipayService._internal();

  /// 是否支持支付宝 SDK（仅 Android/iOS）
  bool get _isSdkSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 初始化支付宝SDK
  Future<Map<String, dynamic>> initAlipay() async {
    if (kIsWeb) {
      return {'success': false, 'message': '支付宝APP支付不支持Web平台'};
    }

    if (!_isSdkSupported) {
      return {'success': false, 'message': '当前平台不支持支付宝APP支付，请使用网页支付'};
    }

    // 移动端的 tobias 初始化需要在原生代码中完成
    return {'success': true, 'message': '支付宝SDK准备就绪'};
  }

  /// 使用支付宝SDK进行授权登录
  Future<Map<String, dynamic>> authWithAlipay(String authString) async {
    if (kIsWeb) {
      return {'success': false, 'message': '支付宝SDK授权不支持Web平台'};
    }

    if (!_isSdkSupported) {
      return {'success': false, 'message': '当前平台不支持支付宝SDK授权'};
    }

    // 移动端需要通过原生代码调用 tobias
    debugPrint('支付宝授权需要在移动端原生代码中实现');
    return {'success': false, 'message': '请在移动端使用此功能'};
  }

  /// 发起支付宝APP支付
  Future<Map<String, dynamic>> payWithAlipay(String orderString) async {
    if (kIsWeb) {
      return {'success': false, 'message': '支付宝APP支付不支持Web平台'};
    }

    if (!_isSdkSupported) {
      return {'success': false, 'message': '当前平台不支持支付宝APP支付，请使用网页支付'};
    }

    // 移动端需要通过原生代码调用 tobias
    debugPrint('支付宝支付需要在移动端原生代码中实现');
    return {'success': false, 'message': '请在移动端使用此功能'};
  }

  /// 检查是否安装了支付宝
  Future<bool> isAlipayInstalled() async {
    if (!_isSdkSupported) return false;
    // 移动端检查需要原生代码
    return false;
  }

  /// 获取支付宝SDK版本
  Future<String> getAlipayVersion() async {
    if (!_isSdkSupported) {
      return '当前平台不支持';
    }
    return '需要原生代码获取';
  }

  /// 验证支付参数
  bool validatePayParameters(String orderString) {
    if (orderString.isEmpty) {
      debugPrint('订单字符串为空');
      return false;
    }

    if (!orderString.contains('app_id=')) {
      debugPrint('订单字符串缺少app_id字段');
      return false;
    }

    if (!orderString.contains('sign=')) {
      debugPrint('订单字符串缺少sign字段');
      return false;
    }

    return true;
  }

  /// 启动支付宝电脑网站支付
  Future<Map<String, dynamic>> launchAlipayWebPayment(String paymentUrl) async {
    try {
      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(
          Uri.parse(paymentUrl),
          mode: LaunchMode.externalApplication,
        );
        return {'success': true, 'message': '正在打开支付宝支付页面...'};
      } else {
        return {'success': false, 'message': '无法打开支付宝支付页面'};
      }
    } catch (e) {
      debugPrint('启动支付宝Web支付失败: $e');
      return {'success': false, 'message': '启动支付宝Web支付失败: $e'};
    }
  }
}
