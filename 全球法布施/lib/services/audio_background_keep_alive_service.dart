import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../core/config/app_config.dart';

/// 音频后台保活服务
/// 
/// 通过循环播放陀罗尼音频来增强后台保活能力。
/// 使用音频播放被系统视为"音频活动"的特性，减少应用被系统杀掉的概率。
/// 
/// 与之前的 TTS 保活不同，音频播放使用独立的系统资源，
/// 不会与法流页面的 TTS 朗读功能冲突。
class AudioBackgroundKeepAliveService {
  static final AudioBackgroundKeepAliveService _instance = AudioBackgroundKeepAliveService._internal();
  factory AudioBackgroundKeepAliveService() => _instance;
  AudioBackgroundKeepAliveService._internal();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;  // 默认静音
  
  // 音频信息
  String _audioName = '';
  
  // 发送进度
  int _sentCount = 0;
  int _totalCount = 0;
  String _currentCountry = '';
  int _loopCount = 0;
  
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;

  /// 默认保活音频URL - 大孔雀明王结界缚魔陀罗尼
  static String get defaultAudioUrl {
    final encodedPath = Uri.encodeComponent(
      'assets/built_in/房山石经陀罗尼梵音音频/M06.29 卍大孔雀明王结界缚魔陀罗尼(大孔雀明王结界缚魔身印陀罗尼)卍.mp3'
    );
    return '${AppConfig.currentBackendUrl}/$encodedPath';
  }

  /// 初始化音频播放器
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Web平台不需要后台保活
    if (kIsWeb) {
      debugPrint('⚠️ Web平台不支持后台保活');
      return;
    }
    
    try {
      _audioPlayer = AudioPlayer();
      
      // 设置循环模式
      await _audioPlayer!.setLoopMode(LoopMode.one);
      
      // 设置初始音量（静音）
      await _audioPlayer!.setVolume(_isMuted ? 0.0 : 0.3);
      
      // 监听播放状态
      _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          // 循环播放，不需要手动处理
        }
      });
      
      // 监听错误
      _audioPlayer!.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace stackTrace) {
          debugPrint('🔇 音频保活 错误: $e');
        },
      );
      
      _isInitialized = true;
      debugPrint('✅ 音频保活服务已初始化');
    } catch (e) {
      debugPrint('❌ 音频保活服务初始化失败: $e');
    }
  }

  /// 开始音频保活
  /// 
  /// [audioUrl] - 可选的自定义音频URL，默认使用大孔雀明王结界缚魔陀罗尼
  /// [audioName] - 音频名称（用于通知栏显示）
  Future<void> start({
    String? audioUrl,
    String? audioName,
    int totalCountries = 0,
  }) async {
    if (_isPlaying) {
      debugPrint('⚠️ 音频保活已在运行中');
      return;
    }
    
    // Web平台不需要后台保活
    if (kIsWeb) return;
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_audioPlayer == null) {
      debugPrint('⚠️ 音频播放器未初始化');
      return;
    }
    
    _audioName = audioName ?? '大孔雀明王结界缚魔陀罗尼';
    _totalCount = totalCountries;
    _sentCount = 0;
    _loopCount = 0;
    _currentCountry = '';
    
    try {
      // 设置音频源
      final url = audioUrl ?? defaultAudioUrl;
      debugPrint('🔇 音频保活启动: $_audioName');
      debugPrint('📥 加载音频: $url');
      
      await _audioPlayer!.setUrl(url);
      
      // 确保音量正确
      await _audioPlayer!.setVolume(_isMuted ? 0.0 : 0.3);
      
      // 开始播放
      await _audioPlayer!.play();
      _isPlaying = true;
      
      debugPrint('✅ 音频保活已启动');
    } catch (e) {
      debugPrint('❌ 启动音频保活失败: $e');
    }
  }

  /// 更新发送进度（用于通知栏显示）
  void updateProgress({
    required int sentCount,
    required int totalCount,
    required String currentCountry,
    int? loopCount,
  }) {
    _sentCount = sentCount;
    _totalCount = totalCount;
    _currentCountry = currentCountry;
    if (loopCount != null) {
      _loopCount = loopCount;
    }
  }

  /// 停止音频保活
  Future<void> stop() async {
    if (!_isPlaying) return;
    
    _isPlaying = false;
    
    try {
      await _audioPlayer?.stop();
      debugPrint('🔇 音频保活已停止');
    } catch (e) {
      debugPrint('❌ 停止音频保活失败: $e');
    }
    
    _audioName = '';
  }

  /// 设置静音状态
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    
    try {
      await _audioPlayer?.setVolume(muted ? 0.0 : 0.3);
      debugPrint('🔇 音频保活静音: $muted');
    } catch (e) {
      debugPrint('❌ 设置静音失败: $e');
    }
  }

  /// 切换静音状态
  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  /// 释放资源
  void dispose() {
    stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
  }
  
  /// 获取当前状态信息
  String get statusInfo {
    if (!_isPlaying) return '未运行';
    
    final muteStatus = _isMuted ? '(静音)' : '(有声)';
    return '$_audioName $muteStatus';
  }
}
