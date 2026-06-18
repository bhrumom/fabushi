import 'desktop_control_models.dart';

class DesktopControlPolicy {
  static const Set<String> supportedTools = {
    'desktop.observe',
    'desktop.screenshot',
    'desktop.windows',
    'desktop.click',
    'desktop.type',
    'desktop.hotkey',
    'desktop.scroll',
    'chrome.tabs',
    'chrome.navigate',
    'chrome.dom_snapshot',
    'chrome.screenshot',
    'chrome.click',
    'chrome.type',
  };

  static const Set<String> readOnlyTools = {
    'desktop.observe',
    'desktop.screenshot',
    'desktop.windows',
    'chrome.tabs',
    'chrome.dom_snapshot',
    'chrome.screenshot',
  };

  static bool isSupported(String toolName) => supportedTools.contains(toolName);

  static bool isReadOnly(String toolName) => readOnlyTools.contains(toolName);

  static bool requiresConfirmation(String toolName) =>
      isSupported(toolName) && !isReadOnly(toolName);

  static String summarize(String toolName, Map<String, dynamic> arguments) {
    switch (toolName) {
      case 'desktop.click':
        return '确认本机点击 (${arguments['x']}, ${arguments['y']})';
      case 'desktop.type':
        return '确认向本机当前焦点输入 ${_describeText(arguments['text'])}';
      case 'desktop.hotkey':
        return '确认发送本机快捷键 ${arguments['keys'] ?? arguments['key']}';
      case 'desktop.scroll':
        return '确认滚动当前本机界面';
      case 'chrome.navigate':
        return '确认 Chrome 导航到 ${arguments['url'] ?? '指定网址'}';
      case 'chrome.click':
        return '确认在 Chrome 页面点击 ${arguments['selector'] ?? '指定位置'}';
      case 'chrome.type':
        return '确认在 Chrome 页面输入 ${_describeText(arguments['text'])}';
      default:
        return '确认执行 $toolName';
    }
  }

  static DesktopControlToolResult unsupportedPlatform(String platform) {
    return DesktopControlToolResult.failure(
      errorCode: 'unsupported_platform',
      message: '当前 $platform 暂不支持系统级电脑控制',
      recoverable: false,
      data: {'platform': platform},
    );
  }

  static String _describeText(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '空文本';
    if (text.length <= 24) return '"$text"';
    return '"${text.substring(0, 24)}..."';
  }
}
