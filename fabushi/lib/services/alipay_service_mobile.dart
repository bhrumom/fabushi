import 'package:tobias/tobias.dart';

final Tobias _tobias = Tobias();

/// 使用 Tobias 进行授权
Future<Map<dynamic, dynamic>> authWithTobias(String authString) async {
  return await _tobias.auth(authString);
}

/// 使用 Tobias 进行支付
Future<Map<dynamic, dynamic>> payWithTobias(String orderString) async {
  return await _tobias.pay(orderString);
}

/// 检查支付宝是否已安装
Future<bool> isAlipayInstalled() async {
  return await _tobias.isAliPayInstalled;
}

/// 获取支付宝版本
Future<String> getAlipayVersion() async {
  return await _tobias.aliPayVersion;
}
