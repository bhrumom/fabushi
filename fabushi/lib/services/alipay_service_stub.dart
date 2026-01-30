/// Stub implementation for platforms that don't support Alipay SDK (Windows, macOS, Linux, Web)

Future<Map<dynamic, dynamic>> authWithTobias(String authString) async {
  return {'resultStatus': '4000', 'memo': '当前平台不支持', 'result': ''};
}

Future<Map<dynamic, dynamic>> payWithTobias(String orderString) async {
  return {'resultStatus': '4000', 'memo': '当前平台不支持', 'result': ''};
}

Future<bool> isAlipayInstalled() async {
  return false;
}

Future<String> getAlipayVersion() async {
  return '不支持';
}
