import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// TTS 单例管理器
/// 确保全局只有一个 TTS 实例，避免多个实例竞争系统资源
class TtsManager {
  static final TtsManager _instance = TtsManager._internal();
  factory TtsManager() => _instance;
  TtsManager._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _deviceBrand = '';
  bool _useFallbackOnly = false;
  
  // 当前活跃的朗读者ID（用于区分不同的 TextContent 实例）
  String? _activeOwnerId;
  
  // 回调
  Function(String text, int start, int end, String word)? _progressCallback;
  VoidCallback? _completionCallback;
  Function(String msg)? _errorCallback;
  
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get useFallbackOnly => _useFallbackOnly;
  String get deviceBrand => _deviceBrand;
  String? get activeOwnerId => _activeOwnerId;

  /// 初始化 TTS（只需调用一次）
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _detectDevice();
      
      _tts = FlutterTts();
      
      await _tts!.setLanguage('zh-CN');
      await _tts!.setSpeechRate(0.9);
      await _tts!.setVolume(1.0);
      await _tts!.awaitSpeakCompletion(true);
      
      _tts!.setProgressHandler((text, start, end, word) {
        _progressCallback?.call(text, start, end, word);
      });
      
      _tts!.setCompletionHandler(() {
        debugPrint('📱 TTS Manager: Playback COMPLETE');
        _isSpeaking = false;
        _completionCallback?.call();
      });
      
      _tts!.setErrorHandler((msg) {
        debugPrint('📱 TTS Manager: Error: $msg');
        _isSpeaking = false;
        _errorCallback?.call(msg);
      });
      
      _isInitialized = true;
      debugPrint('📱 TTS Manager: Initialized | Device=$_deviceBrand | FallbackOnly=$_useFallbackOnly');
    } catch (e) {
      debugPrint('📱 TTS Manager: Init error: $e');
    }
  }
  
  Future<void> _detectDevice() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _deviceBrand = androidInfo.brand.toLowerCase();
        
        const problematicBrands = [
          'huawei', 'honor', 'xiaomi', 'redmi', 'oppo', 
          'vivo', 'oneplus', 'realme', 'meizu',
        ];
        
        _useFallbackOnly = problematicBrands.any((brand) => _deviceBrand.contains(brand));
        debugPrint('📱 TTS Manager: Device brand="$_deviceBrand", useFallbackOnly=$_useFallbackOnly');
      } else if (Platform.isIOS) {
        _deviceBrand = 'apple';
        _useFallbackOnly = false;
      }
    } catch (e) {
      debugPrint('📱 TTS Manager: Device detection failed: $e');
      _useFallbackOnly = true;
    }
  }

  /// 注册朗读者的回调
  /// 新的注册会覆盖旧的，确保视频切换时新实例能够正常接管
  void registerCallbacks({
    required String ownerId,
    Function(String text, int start, int end, String word)? onProgress,
    VoidCallback? onCompletion,
    Function(String msg)? onError,
  }) {
    // 如果有其他owner正在活跃，只记录，不在这里停止
    // 停止操作会在 speak() 方法中处理，那里有足够的延迟
    if (_activeOwnerId != null && _activeOwnerId != ownerId) {
      debugPrint('📱 TTS Manager: Owner $ownerId taking over from $_activeOwnerId');
    }
    
    _activeOwnerId = ownerId;
    _progressCallback = onProgress;
    _completionCallback = onCompletion;
    _errorCallback = onError;
    debugPrint('📱 TTS Manager: Registered owner $ownerId');
  }

  /// 取消注册
  void unregisterCallbacks(String ownerId) {
    if (_activeOwnerId == ownerId) {
      _progressCallback = null;
      _completionCallback = null;
      _errorCallback = null;
      _activeOwnerId = null;
      debugPrint('📱 TTS Manager: Unregistered owner $ownerId');
    }
  }

  /// 开始朗读
  Future<bool> speak(String text, String ownerId) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // 先停止任何正在进行的朗读
    if (_isSpeaking) {
      debugPrint('📱 TTS Manager: Stopping previous speech before starting new one');
      await stop();
      // 等待TTS引擎释放资源，避免 -8 错误
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // 更新活跃朗读者
    _activeOwnerId = ownerId;
    
    try {
      debugPrint('📱 TTS Manager: Starting speech for owner $ownerId (${text.length} chars)');
      _isSpeaking = true;
      final result = await _tts?.speak(text);
      if (result == 0) {
        // 0 表示失败
        debugPrint('📱 TTS Manager: Speak returned failure code');
        _isSpeaking = false;
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('📱 TTS Manager: Speak error: $e');
      _isSpeaking = false;
      return false;
    }
  }

  /// 停止朗读
  Future<void> stop() async {
    if (!_isInitialized) return;
    
    try {
      debugPrint('📱 TTS Manager: Stopping speech');
      await _tts?.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('📱 TTS Manager: Stop error: $e');
    }
  }

  /// 释放资源（通常在应用退出时调用）
  void dispose() {
    _tts?.stop();
    _tts = null;
    _isInitialized = false;
    _isSpeaking = false;
    _activeOwnerId = null;
  }
}
