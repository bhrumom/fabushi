import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../core/config/app_config.dart';

/// iOS 后台音频处理器
/// 使用静音音频保持应用在后台运行，并通过系统媒体控制中心显示发送进度
class IOSBackgroundAudioHandler extends BaseAudioHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _sentCount = 0;
  int _totalCount = 0;
  int _loopCount = 0;

  IOSBackgroundAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    if (!Platform.isIOS) return;

    try {
      // 加载静音音频文件（从后端）
      final silenceUrl = AppConfig.silenceAudioUrl;
      debugPrint('📥 正在从后端加载静音音频: $silenceUrl');

      await _audioPlayer.setUrl(silenceUrl);
      await _audioPlayer.setLoopMode(LoopMode.one); // 循环播放

      debugPrint('✅ iOS 后台音频处理器已初始化');
    } catch (e) {
      debugPrint('❌ iOS 后台音频初始化失败: $e');
    }
  }

  /// 启动后台音频（开始发送时调用）
  Future<void> startBackgroundAudio({
    required String fileName,
    int totalCountries = 0,
  }) async {
    if (!Platform.isIOS || _isPlaying) return;

    try {
      _totalCount = totalCountries;
      _sentCount = 0;
      _loopCount = 0;

      // 设置媒体项信息
      mediaItem.add(MediaItem(
        id: 'dharma_sending',
        title: '正在发送经文',
        artist: fileName,
        artUri: null,
        duration: Duration.zero, // 未知时长
      ));

      // 设置播放状态
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.pause,
        ],
        playing: true,
        processingState: AudioProcessingState.ready,
      ));

      // 开始播放静音音频
      await _audioPlayer.play();
      _isPlaying = true;

      debugPrint('✅ iOS 后台音频已启动');
    } catch (e) {
      debugPrint('❌ 启动 iOS 后台音频失败: $e');
    }
  }

  /// 更新发送进度
  Future<void> updateProgress({
    required int sentCount,
    required int totalCount,
    required String currentCountry,
    int? loopCount,
  }) async {
    if (!Platform.isIOS || !_isPlaying) return;

    try {
      _sentCount = sentCount;
      _totalCount = totalCount;
      if (loopCount != null) {
        _loopCount = loopCount;
      }

      String title = '正在发送经文';
      if (_loopCount > 0) {
        title = '循环发送中 (第 $_loopCount 轮)';
      }

      // 更新媒体控制中心显示
      mediaItem.add(MediaItem(
        id: 'dharma_sending',
        title: title,
        artist: '发送到: $currentCountry ($_sentCount/$_totalCount)',
        artUri: null,
        duration: Duration.zero,
      ));

      debugPrint('📱 已更新 iOS 媒体控制中心: $currentCountry ($_sentCount/$_totalCount)');
    } catch (e) {
      debugPrint('❌ 更新 iOS 进度失败: $e');
    }
  }

  /// 停止后台音频
  Future<void> stopBackgroundAudio() async {
    if (!Platform.isIOS || !_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;

      // 更新播放状态为已停止
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ));

      debugPrint('✅ iOS 后台音频已停止');
    } catch (e) {
      debugPrint('❌ 停止 iOS 后台音频失败: $e');
    }
  }

  /// 显示完成状态
  Future<void> showCompletion({
    required int totalSent,
    required int loopCount,
  }) async {
    if (!Platform.isIOS) return;

    try {
      String message = loopCount > 1
          ? '已完成 $loopCount 轮，共发送到 $totalSent 个国家'
          : '已成功发送到 $totalSent 个国家';

      mediaItem.add(MediaItem(
        id: 'dharma_sending',
        title: '✨ 发送完成',
        artist: message,
        artUri: null,
        duration: Duration.zero,
      ));

      // 2秒后停止音频
      await Future.delayed(const Duration(seconds: 2));
      await stopBackgroundAudio();
    } catch (e) {
      debugPrint('❌ 显示完成状态失败: $e');
    }
  }

  @override
  Future<void> play() async {
    // 用户从媒体控制中心点击播放
    // 在这个场景下，我们不需要实际处理，因为音频一直在播放
    debugPrint('🎵 用户点击播放');
  }

  @override
  Future<void> pause() async {
    // 用户从媒体控制中心点击暂停
    // 在这个场景下，可以暂停发送
    debugPrint('⏸️ 用户点击暂停');
  }

  @override
  Future<void> stop() async {
    await stopBackgroundAudio();
  }

  @override
  Future<void> onTaskRemoved() async {
    // 应用从任务列表移除时
    await stopBackgroundAudio();
    await super.onTaskRemoved();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

/// 创建 iOS 后台音频处理器的工厂方法
Future<IOSBackgroundAudioHandler> initIOSBackgroundAudio() async {
  if (!Platform.isIOS) {
    throw UnsupportedError('iOS 后台音频仅在 iOS 平台可用');
  }

  return await AudioService.init(
    builder: () => IOSBackgroundAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.fabushi.app.audio',
      androidNotificationChannelName: '大乘',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
    ),
  );
}
