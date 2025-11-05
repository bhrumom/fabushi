// 平台排除文件
// 用于解决平台兼容性问题

import 'package:flutter/foundation.dart';

// 检查当前平台是否支持特定功能
class PlatformSupport {
  // 检查文件选择器是否支持当前平台
  static bool get isFilePickerSupported {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    if (defaultTargetPlatform == TargetPlatform.macOS) return true;
    return false;
  }

  // 检查通知是否支持当前平台
  static bool get isNotificationSupported {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    if (defaultTargetPlatform == TargetPlatform.macOS) return true;
    return false;
  }

  // 检查WiFi功能是否支持当前平台
  static bool get isWifiSupported {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    return false;
  }
}
