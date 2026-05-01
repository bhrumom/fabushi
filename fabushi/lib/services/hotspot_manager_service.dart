import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 热点管理服务
/// 用于管理设备的 Wi-Fi 热点功能
///
/// 平台限制：
/// - iOS: 无法自动开启热点，只能引导用户到设置页面
/// - Android: Android 10+ 限制严格，需要 WRITE_SETTINGS 权限
/// - macOS: 可以通过命令行开启
class HotspotManagerService {
  static const MethodChannel _channel = MethodChannel(
    'com.fabushi.app/hotspot',
  );

  bool _isHotspotEnabled = false;

  /// 检查热点是否已开启
  Future<bool> isHotspotEnabled() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        return await _checkAndroidHotspot();
      } else if (Platform.isIOS) {
        // iOS 无法检测热点状态
        return _isHotspotEnabled;
      } else if (Platform.isMacOS) {
        return await _checkMacOSHotspot();
      }
    } catch (e) {
      debugPrint('检查热点状态失败: $e');
    }
    return false;
  }

  /// 尝试开启热点
  /// 返回 true 表示成功开启或已引导用户
  Future<HotspotResult> enableHotspot() async {
    if (kIsWeb) {
      return HotspotResult(success: false, message: 'Web 平台不支持热点功能');
    }

    try {
      if (Platform.isAndroid) {
        return await _enableAndroidHotspot();
      } else if (Platform.isIOS) {
        return await _enableIOSHotspot();
      } else if (Platform.isMacOS) {
        return await _enableMacOSHotspot();
      }
    } catch (e) {
      debugPrint('开启热点失败: $e');
      return HotspotResult(success: false, message: '开启热点失败: $e');
    }

    return HotspotResult(success: false, message: '当前平台不支持');
  }

  /// 关闭热点
  Future<void> disableHotspot() async {
    if (kIsWeb) return;

    try {
      if (Platform.isMacOS) {
        await _disableMacOSHotspot();
      }
      // Android/iOS 通常不需要自动关闭
    } catch (e) {
      debugPrint('关闭热点失败: $e');
    }

    _isHotspotEnabled = false;
  }

  // ========== Android 实现 ==========

  Future<bool> _checkAndroidHotspot() async {
    try {
      final result = await _channel.invokeMethod<bool>('isHotspotEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Android 检查热点失败: $e');
      return false;
    }
  }

  Future<HotspotResult> _enableAndroidHotspot() async {
    try {
      // 尝试通过原生代码开启
      final result = await _channel.invokeMethod<bool>('enableHotspot');
      if (result == true) {
        _isHotspotEnabled = true;
        return HotspotResult(success: true, message: '热点已开启');
      }
    } catch (e) {
      debugPrint('Android 原生开启热点失败: $e');
    }

    // 如果原生方法失败，引导用户手动开启
    return await _openAndroidHotspotSettings();
  }

  Future<HotspotResult> _openAndroidHotspotSettings() async {
    try {
      // 尝试打开热点设置页面
      final uri = Uri.parse('android.settings.TETHER_SETTINGS');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return HotspotResult(
          success: true,
          needsManualAction: true,
          message: '请在设置中开启"便携式热点"',
        );
      }

      // 备用：打开无线设置
      final wifiUri = Uri.parse('android.settings.WIRELESS_SETTINGS');
      if (await canLaunchUrl(wifiUri)) {
        await launchUrl(wifiUri);
        return HotspotResult(
          success: true,
          needsManualAction: true,
          message: '请在设置中开启热点',
        );
      }
    } catch (e) {
      debugPrint('打开 Android 设置失败: $e');
    }

    return HotspotResult(
      success: false,
      needsManualAction: true,
      message: '请手动开启热点：设置 > 网络 > 热点',
    );
  }

  // ========== iOS 实现 ==========

  Future<HotspotResult> _enableIOSHotspot() async {
    // iOS 无法自动开启热点，只能引导用户
    try {
      // 尝试打开设置 App
      final uri = Uri.parse('App-Prefs:INTERNET_TETHERING');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _isHotspotEnabled = true; // 假设用户会开启
        return HotspotResult(
          success: true,
          needsManualAction: true,
          message: '请开启"个人热点"',
        );
      }

      // 备用：打开设置主页
      final settingsUri = Uri.parse('app-settings:');
      if (await canLaunchUrl(settingsUri)) {
        await launchUrl(settingsUri);
        return HotspotResult(
          success: true,
          needsManualAction: true,
          message: '请前往"个人热点"并开启',
        );
      }
    } catch (e) {
      debugPrint('打开 iOS 设置失败: $e');
    }

    return HotspotResult(
      success: false,
      needsManualAction: true,
      message: '请手动开启热点：设置 > 个人热点',
    );
  }

  // ========== macOS 实现 ==========

  Future<bool> _checkMacOSHotspot() async {
    try {
      final result = await Process.run('networksetup', [
        '-getairportnetwork',
        'en0',
      ]);
      // 检查是否有活动的共享网络
      return result.stdout.toString().contains('Internet Sharing');
    } catch (e) {
      return false;
    }
  }

  Future<HotspotResult> _enableMacOSHotspot() async {
    try {
      // macOS 可以通过命令行开启互联网共享
      // 但需要管理员权限，这里引导用户手动开启

      // 尝试打开系统偏好设置的共享面板
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.preferences.sharing',
      ]);

      _isHotspotEnabled = true;
      return HotspotResult(
        success: true,
        needsManualAction: true,
        message: '请在"共享"中开启"互联网共享"',
      );
    } catch (e) {
      debugPrint('macOS 开启热点失败: $e');
      return HotspotResult(
        success: false,
        needsManualAction: true,
        message: '请手动开启：系统偏好设置 > 共享 > 互联网共享',
      );
    }
  }

  Future<void> _disableMacOSHotspot() async {
    // macOS 关闭热点需要管理员权限，暂不实现
    _isHotspotEnabled = false;
  }

  bool get isHotspotEnabledSync => _isHotspotEnabled;
}

/// 热点操作结果
class HotspotResult {
  final bool success;
  final bool needsManualAction;
  final String message;

  HotspotResult({
    required this.success,
    this.needsManualAction = false,
    required this.message,
  });
}
