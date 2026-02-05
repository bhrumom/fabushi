// 平台存根文件 - 用于非Web平台提供空实现
// 当 dart:html 不可用时，此文件会被导入

class Window {
  void addEventListener(String type, Function listener) {}
  void removeEventListener(String type, Function listener) {}
  void open(String url, String target) {}
  LocalStorage get localStorage => LocalStorage();
}

class LocalStorage {
  operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  void remove(String key) {}
}

class Event {}

class MessageEvent implements Event {
  dynamic data;
}

// EventListener 类型定义
typedef EventListener = Function(Event);

// 创建全局的 window 对象
final Window window = Window();

// 导出一个模拟的 html 命名空间
abstract class html {
  static final Window window = Window();
  static void addEventListener(String type, EventListener listener) {}
  static void removeEventListener(String type, EventListener listener) {}
}
