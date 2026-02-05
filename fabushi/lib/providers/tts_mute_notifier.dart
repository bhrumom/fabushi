import 'package:flutter/foundation.dart';
import '../services/app_settings.dart';

/// 管理TTS静音状态的Notifier
/// 
/// 负责：
/// - 启动时加载默认静音设置
/// - 提供运行时静音切换功能
/// - 持久化用户的静音偏好
class TtsMuteNotifier extends ChangeNotifier {
  bool _isMuted = true; // 默认静音
  bool _initialized = false;
  
  /// TTS是否静音
  bool get isMuted => _isMuted;
  
  /// 是否已初始化
  bool get initialized => _initialized;
  
  /// 初始化 - 从持久化存储加载静音状态
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _isMuted = await AppSettings.getTtsMuted();
      _initialized = true;
      debugPrint('📱 TtsMute: Initialized, muted=$_isMuted');
      notifyListeners();
    } catch (e) {
      debugPrint('📱 TtsMute: Initialize error: $e');
      _isMuted = true; // 错误时默认静音
      _initialized = true;
    }
  }
  
  /// 切换静音状态
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    debugPrint('📱 TtsMute: Toggled to ${_isMuted ? "MUTED" : "UNMUTED"}');
    await AppSettings.setTtsMuted(_isMuted);
    notifyListeners();
  }
  
  /// 设置静音状态
  Future<void> setMuted(bool muted) async {
    if (_isMuted != muted) {
      _isMuted = muted;
      debugPrint('📱 TtsMute: Set to ${muted ? "MUTED" : "UNMUTED"}');
      await AppSettings.setTtsMuted(muted);
      notifyListeners();
    }
  }
}
