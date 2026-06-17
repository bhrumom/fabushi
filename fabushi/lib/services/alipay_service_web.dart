import 'dart:html' as html;

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
    final uri = Uri.tryParse(paymentUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return {'success': false, 'message': '支付宝网页支付链接无效'};
    }

    html.window.location.assign(paymentUrl);
    return {'success': true, 'message': '正在打开支付宝支付页面...'};
  }
}
