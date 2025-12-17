import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

/// 音频后台保活服务
/// 
/// 通过循环播放陀罗尼音频来增强后台保活能力。
/// 使用音频播放被系统视为"音频活动"的特性，减少应用被系统杀掉的概率。
/// 
/// 与之前的 TTS 保活不同，音频播放使用独立的系统资源，
/// 不会与法流页面的 TTS 朗读功能冲突。
/// 
/// 音频会缓存到本地，避免每次都从网络加载。
class AudioBackgroundKeepAliveService {
  static final AudioBackgroundKeepAliveService _instance = AudioBackgroundKeepAliveService._internal();
  factory AudioBackgroundKeepAliveService() => _instance;
  AudioBackgroundKeepAliveService._internal();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;  // 默认静音
  bool _isAudioReady = false;  // 音频是否已加载完成
  
  // 音频信息
  String _audioName = '';
  
  // 发送进度
  int _sentCount = 0;
  int _totalCount = 0;
  String _currentCountry = '';
  int _loopCount = 0;
  
  // 缓存相关
  static const String _cacheFileName = 'keep_alive_dharani.mp3';
  
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;

  /// 默认保活音频URL - 大孔雀明王结界缚魔陀罗尼
  static String get defaultAudioUrl {
    final encodedPath = Uri.encodeComponent(
      'assets/built_in/房山石经陀罗尼梵音音频/M06.29 卍大孔雀明王结界缚魔陀罗尼(大孔雀明王结界缚魔身印陀罗尼)卍.mp3'
    );
    return '${AppConfig.currentBackendUrl}/$encodedPath';
  }
  
  /// 获取缓存目录
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }
  
  /// 获取缓存文件路径
  Future<String> _getCacheFilePath() async {
    final cacheDir = await _getCacheDir();
    return '${cacheDir.path}/$_cacheFileName';
  }
  
  /// 检查音频是否已缓存
  Future<bool> _isAudioCached() async {
    if (kIsWeb) return false;
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      return await file.exists() && await file.length() > 0;
    } catch (e) {
      return false;
    }
  }
  
  /// 下载并缓存音频
  Future<String?> _downloadAndCacheAudio(String url) async {
    if (kIsWeb) return null;
    
    try {
      debugPrint('📥 下载音频到本地缓存...');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('下载音频超时');
        },
      );
      
      if (response.statusCode == 200) {
        final filePath = await _getCacheFilePath();
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        debugPrint('✅ 音频已缓存到: $filePath (${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
        return filePath;
      } else {
        debugPrint('❌ 下载音频失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 下载音频异常: $e');
      return null;
    }
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
    
    // 设置音频源
    final url = audioUrl ?? defaultAudioUrl;
    debugPrint('🔇 音频保活启动: $_audioName');
    debugPrint('📥 加载音频: $url');
    
    // 使用非阻塞方式启动音频，不阻塞主发送流程
    _startAudioAsync(url);
    
    // 立即标记为已启动，让发送流程继续
    _isPlaying = true;
    debugPrint('✅ 音频保活已启动（异步加载中）');
  }
  
  /// 异步启动音频播放（不阻塞调用者）
  /// 优先使用本地缓存，无缓存则下载并保存
  void _startAudioAsync(String url) {
    _isAudioReady = false;
    Future(() async {
      try {
        String? audioSource;
        
        // 检查是否有本地缓存
        if (await _isAudioCached()) {
          final cachedPath = await _getCacheFilePath();
          debugPrint('📂 使用本地缓存音频: $cachedPath');
          audioSource = cachedPath;
          
          // 从本地文件加载
          await _audioPlayer!.setFilePath(cachedPath).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw TimeoutException('本地音频加载超时');
            },
          );
        } else {
          // 没有缓存，尝试下载到本地
          debugPrint('📥 首次加载，下载并缓存音频...');
          final cachedPath = await _downloadAndCacheAudio(url);
          
          if (cachedPath != null) {
            // 下载成功，使用本地文件
            audioSource = cachedPath;
            await _audioPlayer!.setFilePath(cachedPath).timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                throw TimeoutException('本地音频加载超时');
              },
            );
          } else {
            // 下载失败，fallback 到网络 URL
            debugPrint('⚠️ 下载失败，尝试直接播放网络音频');
            audioSource = url;
            await _audioPlayer!.setUrl(url).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('网络音频加载超时');
              },
            );
          }
        }
        
        // 标记音频已准备好
        _isAudioReady = true;
        
        // 确保音量正确（使用当前静音状态）
        await _audioPlayer!.setVolume(_isMuted ? 0.0 : 0.3);
        
        // 开始播放
        await _audioPlayer!.play();
        
        debugPrint('✅ 音频保活已开始播放 (静音: $_isMuted, 来源: ${audioSource == url ? "网络" : "本地缓存"})');
      } catch (e) {
        debugPrint('⚠️ 音频保活加载失败: $e（不影响发送）');
        // 失败不影响发送流程，只是没有后台保活音频
      }
    });
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
    _isAudioReady = false;
    
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
    
    // 如果音频还没准备好，只更新状态，等音频加载完成后会自动应用
    if (!_isAudioReady) {
      debugPrint('🔇 音频保活静音状态已保存: $muted（音频加载中，稍后自动应用）');
      return;
    }
    
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
