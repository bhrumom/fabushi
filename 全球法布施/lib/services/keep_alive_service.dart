import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'workmanager_keep_alive.dart';
import 'memory_manager.dart';

/// 统一保活服务
/// 
/// 基于第一性原理设计的后台保活服务，采用多重保活策略：
/// 
/// 【核心原理】
/// 移动操作系统杀后台应用的根本原因是"系统认为该应用不重要"。
/// 本服务通过以下方式提升应用重要性：
/// 
/// 1. 【系统级MediaSession】使用 audio_service 注册到系统媒体控制中心
/// 2. 【音频活动】持续播放陀罗尼音频（可静音），被系统视为"音频活动"
/// 3. 【前台服务】配合 ForegroundServiceManager 显示持续通知
/// 
/// 【与原实现的区别】
/// - 原实现：just_audio + flutter_foreground_task 分离运行
/// - 新实现：audio_service + just_audio 集成，统一管理MediaSession
class KeepAliveAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true; // 默认静音
  
  // 音频信息
  String _audioName = '';
  String? _cachedAudioPath;
  
  // 发送进度
  int _sentCount = 0;
  int _totalCount = 0;
  String _currentCountry = '';
  int _loopCount = 0;
  
  // 缓存相关
  static const String _cacheFileName = 'keep_alive_dharani.mp3';
  
  // 心跳定时器 - 定期发送状态更新，保持服务活跃
  Timer? _heartbeatTimer;
  int _heartbeatCount = 0;
  
  /// 是否服务正在运行（包括音频加载中）
  /// 这个标志在 startKeepAlive 调用后立即为 true
  bool get isPlaying => _isPlaying;
  
  /// 音频是否真正在播放中（检查实际播放器状态）
  bool get isActuallyPlaying => _audioPlayer.playing;
  
  bool get isMuted => _isMuted;
  
  /// 默认保活音频URL - 大孔雀明王结界缚魔陀罗尼
  static String get defaultAudioUrl {
    final encodedPath = Uri.encodeComponent(
      'assets/built_in/房山石经陀罗尼梵音音频/M06.29 卍大孔雀明王结界缚魔陀罗尼(大孔雀明王结界缚魔身印陀罗尼)卍.mp3'
    );
    return '${AppConfig.currentBackendUrl}/$encodedPath';
  }

  KeepAliveAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    
    try {
      // 设置循环模式
      await _audioPlayer.setLoopMode(LoopMode.one);
      
      // 设置初始音量（静音）
      await _audioPlayer.setVolume(_isMuted ? 0.0 : 0.3);
      
      // 监听播放状态变化，同步到 audio_service
      _audioPlayer.playerStateStream.listen((state) {
        _broadcastState();
      });
      
      // 监听播放位置变化
      _audioPlayer.positionStream.listen((position) {
        // 每30秒输出一次位置日志
        if (position.inSeconds > 0 && position.inSeconds % 30 == 0) {
          debugPrint('🔊 保活音频播放位置: ${position.inSeconds}s');
        }
      });
      
      // 监听错误
      _audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace stackTrace) {
          debugPrint('🔇 保活音频错误: $e');
          // 发生错误时尝试重新加载
          _tryReload();
        },
      );
      
      _isInitialized = true;
      debugPrint('✅ KeepAliveAudioHandler 已初始化');
    } catch (e) {
      debugPrint('❌ KeepAliveAudioHandler 初始化失败: $e');
    }
  }

  /// 尝试重新加载音频
  Future<void> _tryReload() async {
    if (!_isPlaying) return;
    
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (_cachedAudioPath != null) {
        await _audioPlayer.setFilePath(_cachedAudioPath!);
        await _audioPlayer.play();
        debugPrint('✅ 保活音频已重新加载');
      }
    } catch (e) {
      debugPrint('❌ 重新加载保活音频失败: $e');
    }
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
      debugPrint('📥 下载保活音频到本地缓存...');
      
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
        
        debugPrint('✅ 保活音频已缓存到: $filePath (${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
        return filePath;
      } else {
        debugPrint('❌ 下载保活音频失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 下载保活音频异常: $e');
      return null;
    }
  }

  /// 开始保活音频播放
  /// 
  /// [audioUrl] - 可选的自定义音频URL
  /// [audioName] - 音频名称
  /// [totalCountries] - 总国家数（用于显示）
  Future<void> startKeepAlive({
    String? audioUrl,
    String? audioName,
    int totalCountries = 0,
  }) async {
    if (_isPlaying) {
      debugPrint('⚠️ 保活音频已在运行中');
      return;
    }
    
    if (kIsWeb) return;
    
    if (!_isInitialized) {
      await _init();
    }
    
    _audioName = audioName ?? '大孔雀明王结界缚魔陀罗尼';
    _totalCount = totalCountries;
    _sentCount = 0;
    _loopCount = 0;
    _currentCountry = '';
    
    // 设置媒体项信息（显示在系统媒体控制中心）
    mediaItem.add(MediaItem(
      id: 'keep_alive_dharani',
      title: '全球法布施',
      artist: _audioName,
      album: '后台保活中',
      duration: Duration.zero,
    ));
    
    // 异步加载音频
    _loadAndPlayAsync(audioUrl ?? defaultAudioUrl);
    
    // 启动心跳定时器
    _startHeartbeat();
    
    _isPlaying = true;
    debugPrint('✅ 保活服务已启动（异步加载中）');
  }

  /// 异步加载并播放音频
  Future<void> _loadAndPlayAsync(String url) async {
    try {
      // 检查是否有本地缓存
      if (await _isAudioCached()) {
        _cachedAudioPath = await _getCacheFilePath();
        debugPrint('📂 使用本地缓存保活音频: $_cachedAudioPath');
        await _audioPlayer.setFilePath(_cachedAudioPath!);
      } else {
        // 没有缓存，尝试下载到本地
        debugPrint('📥 首次加载，下载并缓存保活音频...');
        _cachedAudioPath = await _downloadAndCacheAudio(url);
        
        if (_cachedAudioPath != null) {
          await _audioPlayer.setFilePath(_cachedAudioPath!);
        } else {
          // 下载失败，fallback 到网络 URL
          debugPrint('⚠️ 下载失败，尝试直接播放网络音频');
          await _audioPlayer.setUrl(url);
        }
      }
      
      // 确保音量正确
      await _audioPlayer.setVolume(_isMuted ? 0.0 : 0.3);
      
      // 开始播放
      await _audioPlayer.play();
      
      // 广播播放状态
      _broadcastState();
      
      debugPrint('✅ 保活音频已开始播放 (静音: $_isMuted)');
    } catch (e) {
      debugPrint('⚠️ 保活音频加载失败: $e');
    }
  }

  /// 广播播放状态到系统
  void _broadcastState() {
    final playing = _audioPlayer.playing;
    final processingState = _audioPlayer.processingState;
    
    AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        // 循环播放时，completed 也视为 ready
        audioProcessingState = AudioProcessingState.ready;
        break;
    }
    
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.pause,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0],
      processingState: audioProcessingState,
      playing: playing,
      updatePosition: _audioPlayer.position,
      bufferedPosition: _audioPlayer.bufferedPosition,
      speed: _audioPlayer.speed,
    ));
  }

  /// 启动心跳定时器
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatCount = 0;
    
    // 每5秒发送一次心跳，保持服务活跃
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _heartbeatCount++;
      
      // 定期更新媒体项信息，让系统知道服务仍在运行
      _updateMediaItemForHeartbeat();
      
      // 每 12 次心跳（60秒）执行一次状态持久化和内存清理
      if (_heartbeatCount % 12 == 0) {
        debugPrint('💓 保活心跳 #$_heartbeatCount - 播放中: ${_audioPlayer.playing}');
        
        // 更新 WorkManager 状态时间戳
        WorkManagerKeepAlive.updateLastActiveTime();
        
        // 触发内存清理检查
        MemoryManager.instance.trimCacheIfNeeded();
      }
    });
  }

  /// 更新媒体项（心跳）
  void _updateMediaItemForHeartbeat() {
    String subtitle;
    if (_currentCountry.isNotEmpty) {
      subtitle = '$_currentCountry ($_sentCount/$_totalCount)';
    } else if (_totalCount > 0) {
      subtitle = '准备发送到 $_totalCount 个国家';
    } else {
      subtitle = '后台保活中';
    }
    
    if (_loopCount > 0) {
      subtitle = '第 $_loopCount 轮 · $subtitle';
    }
    
    mediaItem.add(MediaItem(
      id: 'keep_alive_dharani',
      title: '全球法布施',
      artist: subtitle,
      album: _audioName,
      duration: _audioPlayer.duration ?? Duration.zero,
    ));
  }

  /// 更新发送进度
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
    
    // 立即更新媒体项
    _updateMediaItemForHeartbeat();
  }

  /// 停止保活
  @override
  Future<void> stop() async {
    if (!_isPlaying) return;
    
    _isPlaying = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    try {
      await _audioPlayer.stop();
      
      // 更新播放状态为已停止
      playbackState.add(PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      
      debugPrint('🔇 保活音频已停止');
    } catch (e) {
      debugPrint('❌ 停止保活音频失败: $e');
    }
    
    _audioName = '';
    _cachedAudioPath = null;
  }

  /// 设置静音状态
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    
    try {
      await _audioPlayer.setVolume(muted ? 0.0 : 0.3);
      debugPrint('🔇 保活音频静音: $muted');
    } catch (e) {
      debugPrint('❌ 设置静音失败: $e');
    }
  }

  /// 切换静音状态
  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  // BaseAudioHandler 必须实现的方法
  @override
  Future<void> play() async {
    await _audioPlayer.play();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 释放资源
  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
    _isInitialized = false;
  }
  
  /// 获取当前状态信息
  String get statusInfo {
    if (!_isPlaying) return '未运行';
    
    final muteStatus = _isMuted ? '(静音)' : '(有声)';
    return '$_audioName $muteStatus';
  }
}

/// 统一保活服务管理器
/// 
/// 封装保活服务的初始化和生命周期管理
class KeepAliveService {
  static KeepAliveService? _instance;
  static KeepAliveAudioHandler? _audioHandler;
  
  // 初始化锁，防止竞态条件
  static Completer<void>? _initCompleter;
  static bool _isInitializing = false;
  
  KeepAliveService._();
  
  static KeepAliveService get instance {
    _instance ??= KeepAliveService._();
    return _instance!;
  }
  
  /// 获取音频处理器
  KeepAliveAudioHandler? get audioHandler => _audioHandler;
  
  /// 是否已初始化
  bool get isInitialized => _audioHandler != null;
  
  /// 初始化保活服务
  /// 
  /// 必须在应用启动时调用一次。
  /// 使用锁机制防止并发初始化导致的 AudioService 重复初始化错误。
  Future<void> initialize() async {
    // 如果已经初始化完成，直接返回
    if (_audioHandler != null) {
      debugPrint('⚠️ KeepAliveService 已初始化');
      return;
    }
    
    // 如果正在初始化中，等待初始化完成
    if (_isInitializing && _initCompleter != null) {
      debugPrint('⏳ KeepAliveService 初始化中，等待完成...');
      await _initCompleter!.future;
      return;
    }
    
    if (kIsWeb) {
      debugPrint('⚠️ Web平台不支持后台保活');
      return;
    }
    
    // 标记开始初始化，防止并发
    _isInitializing = true;
    _initCompleter = Completer<void>();
    
    try {
      _audioHandler = await AudioService.init(
        builder: () => KeepAliveAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.ombhrum.fabushi.keep_alive',
          androidNotificationChannelName: '全球法布施',
          androidNotificationChannelDescription: '保持应用在后台运行，确保全球发送不中断',
          // Android 通知配置 - 显示音乐播放器风格通知
          // 设置 ongoing=false, stopOnPause=false 确保通知始终显示
          androidNotificationOngoing: false,  // 允许滑动关闭（但我们会持续播放所以不会消失）
          androidStopForegroundOnPause: false, // 暂停时保持前台服务和通知
          androidResumeOnClick: true,  // 点击通知返回应用
          androidShowNotificationBadge: true,  // 显示角标
          // 通知图标
          androidNotificationIcon: 'mipmap/ic_launcher',
          // 封面图压缩
          artDownscaleWidth: 300,
          artDownscaleHeight: 300,
        ),
      );
      
      debugPrint('✅ KeepAliveService 已初始化');
    } catch (e) {
      debugPrint('❌ KeepAliveService 初始化失败: $e');
      
      // 热重载或重复初始化场景：尝试创建新的 audio handler 实例
      // AudioService 已经初始化过了，我们直接创建一个本地的 handler 使用
      if (e.toString().contains('_cacheManager == null')) {
        debugPrint('🔄 检测到 AudioService 已初始化，创建本地音频处理器...');
        _audioHandler = KeepAliveAudioHandler();
        debugPrint('✅ 本地音频处理器已创建（降级模式）');
      }
    } finally {
      _isInitializing = false;
      _initCompleter?.complete();
    }
  }
  
  /// 开始保活
  Future<void> start({
    String? audioUrl,
    String? audioName,
    int totalCountries = 0,
  }) async {
    if (_audioHandler == null) {
      await initialize();
    }
    
    await _audioHandler?.startKeepAlive(
      audioUrl: audioUrl,
      audioName: audioName,
      totalCountries: totalCountries,
    );
  }
  
  /// 停止保活
  Future<void> stop() async {
    await _audioHandler?.stop();
  }
  
  /// 更新进度
  void updateProgress({
    required int sentCount,
    required int totalCount,
    required String currentCountry,
    int? loopCount,
  }) {
    _audioHandler?.updateProgress(
      sentCount: sentCount,
      totalCount: totalCount,
      currentCountry: currentCountry,
      loopCount: loopCount,
    );
  }
  
  /// 设置静音
  Future<void> setMuted(bool muted) async {
    await _audioHandler?.setMuted(muted);
  }
  
  /// 切换静音
  Future<void> toggleMute() async {
    await _audioHandler?.toggleMute();
  }
  
  /// 是否正在播放（服务已启动）
  bool get isPlaying => _audioHandler?.isPlaying ?? false;
  
  /// 音频是否真正在播放中
  bool get isActuallyPlaying => _audioHandler?.isActuallyPlaying ?? false;
  
  /// 是否静音
  bool get isMuted => _audioHandler?.isMuted ?? true;
  
  /// 状态信息
  String get statusInfo => _audioHandler?.statusInfo ?? '未初始化';
}
