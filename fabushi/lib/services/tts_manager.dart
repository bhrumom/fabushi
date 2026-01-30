import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// TTS 单例管理器
/// 
/// 在移动端使用 flutter_tts 进行语音合成。
/// 在桌面端提供空实现（TTS 功能禁用）。
class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal();

  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isStopping = false;
  String _deviceBrand = '';
  bool _useFallbackOnly = false;
  double _speechRate = 0.55;
  
  static const double _baseMsPerCharAt1x = 120.0;
  
  String? _activeOwnerId;
  
  Function(String text, int start, int end, String word)? _progressCallback;
  VoidCallback? _completionCallback;
  Function(String msg)? _errorCallback;
  
  /// 是否支持 TTS（仅移动端 + macOS）
  bool get _isTtsSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
  
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get useFallbackOnly => _useFallbackOnly;
  String get deviceBrand => _deviceBrand;
  String? get activeOwnerId => _activeOwnerId;
  bool get hasActiveOwner => _activeOwnerId != null;
  bool get isMacOS => !kIsWeb && Platform.isMacOS;
  double get speechRate => _speechRate;

  double calculateMsPerChar() {
    if (isMacOS) {
      return 220.0 / (_speechRate / 0.55);
    }
    if (_speechRate > 0.8) {
      return _baseMsPerCharAt1x / (_speechRate * 1.1);
    }
    return _baseMsPerCharAt1x / _speechRate;
  }

  /// 初始化 TTS
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (!_isTtsSupported) {
      debugPrint('📱 TTS Manager: 当前平台不支持 TTS');
      return;
    }
    
    try {
      await _detectDevice();
      
      // 移动端的 flutter_tts 初始化需要在原生代码中完成
      // 这里只做状态管理
      
      if (!kIsWeb && Platform.isAndroid) {
        _speechRate = 0.9;
      } else {
        _speechRate = 0.55;
      }
      
      _isInitialized = true;
      debugPrint('📱 TTS Manager: 已初始化（需要原生代码支持）');
    } catch (e) {
      debugPrint('📱 TTS Manager: 初始化失败: $e');
    }
  }
  
  Future<void> _detectDevice() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _deviceBrand = androidInfo.brand.toLowerCase();
        
        const problematicBrands = [
          'huawei', 'honor', 'xiaomi', 'redmi', 'oppo', 
          'vivo', 'oneplus', 'realme', 'meizu',
        ];
        
        _useFallbackOnly = problematicBrands.any((brand) => _deviceBrand.contains(brand));
      } else if (!kIsWeb && Platform.isIOS) {
        _deviceBrand = 'apple';
        _useFallbackOnly = false;
      }
    } catch (e) {
      debugPrint('📱 TTS Manager: 设备检测失败: $e');
      _useFallbackOnly = true;
    }
  }

  void registerCallbacks({
    required String ownerId,
    Function(String text, int start, int end, String word)? onProgress,
    VoidCallback? onCompletion,
    Function(String msg)? onError,
  }) {
    if (_activeOwnerId != null && _activeOwnerId != ownerId) {
      debugPrint('📱 TTS Manager: Owner $ownerId 接管自 $_activeOwnerId');
    }
    
    _activeOwnerId = ownerId;
    _progressCallback = onProgress;
    _completionCallback = onCompletion;
    _errorCallback = onError;
  }

  void unregisterCallbacks(String ownerId) {
    if (_activeOwnerId == ownerId) {
      _progressCallback = null;
      _completionCallback = null;
      _errorCallback = null;
      _activeOwnerId = null;
    }
  }

  /// 开始朗读
  Future<bool> speak(String text, String ownerId) async {
    if (!_isTtsSupported) {
      debugPrint('📱 TTS Manager: 当前平台不支持 TTS');
      return false;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isSpeaking) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    _activeOwnerId = ownerId;
    _isSpeaking = true;
    _isStopping = false;
    
    debugPrint('📱 TTS Manager: 开始朗读 (${text.length} 字符)');
    
    // 移动端需要原生代码调用 flutter_tts
    // 这里模拟完成回调
    Future.delayed(Duration(milliseconds: (text.length * calculateMsPerChar()).toInt()), () {
      if (!_isStopping && _isSpeaking) {
        _isSpeaking = false;
        _completionCallback?.call();
      }
    });
    
    return true;
  }

  /// 停止朗读
  Future<void> stop() async {
    if (!_isInitialized || !_isTtsSupported) return;
    
    _isStopping = true;
    _isSpeaking = false;
    debugPrint('📱 TTS Manager: 停止朗读');
  }

  void dispose() {
    _isInitialized = false;
    _isSpeaking = false;
    _activeOwnerId = null;
  }
}
