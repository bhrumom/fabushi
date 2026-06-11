class AlipayService {
  Future<Map<String, dynamic>> initAlipay() async {
    return {'success': false, 'message': '支付宝 APP 支付不支持 Web 平台'};
  }

  Future<Map<String, dynamic>> payWithAlipay(String orderString) async {
    return {'success': false, 'message': '请在 App 端使用支付宝解锁'};
  }
}
