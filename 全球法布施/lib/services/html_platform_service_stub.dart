// Stub实现 - 用于条件导入
class HtmlServiceStub {
  void addMessageListener(Function(dynamic) listener) {}
  void removeMessageListener(Function(dynamic) listener) {}
  void openWindow(String url, String target) {}
  String? getLocalStorageItem(String key) => null;
  void setLocalStorageItem(String key, String value) {}
  void removeLocalStorageItem(String key) {}
}

HtmlServiceStub createHtmlService() => HtmlServiceStub();