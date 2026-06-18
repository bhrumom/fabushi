import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class AlipayService {
  Future<Map<String, dynamic>> initAlipay() async {
    return {'success': false, 'message': '支付宝 APP 支付不支持 Web 平台'};
  }

  Future<Map<String, dynamic>> payWithAlipay(String orderString) async {
    return {'success': false, 'message': '请在 App 端使用支付宝解锁'};
  }

  Future<Map<String, dynamic>> payWithAlipayWeb(String paymentUrl) async {
    return launchAlipayWebPayment(paymentUrl);
  }

  Future<Map<String, dynamic>> launchAlipayWebPayment(String paymentUrl) async {
    try {
      final uri = Uri.tryParse(paymentUrl);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return {'success': false, 'message': '支付宝网页支付链接无效'};
      }

      if (!await canLaunchUrl(uri)) {
        return {'success': false, 'message': '无法打开支付宝支付页面'};
      }

      await launchUrl(uri, webOnlyWindowName: '_self');
      return {'success': true, 'message': '正在打开支付宝支付页面...'};
    } catch (e) {
      debugPrint('启动支付宝Web支付失败: $e');
      return {'success': false, 'message': '启动支付宝Web支付失败: $e'};
    }
  }
}
