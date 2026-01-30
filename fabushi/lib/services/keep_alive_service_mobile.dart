import 'package:audio_service/audio_service.dart';
import 'keep_alive_service.dart';

/// 初始化 AudioService（仅移动端调用）
Future<KeepAliveAudioHandler> initializeAudioService() async {
  // 这里需要返回一个符合类型的处理器
  // 由于 KeepAliveAudioHandler 在主文件中已简化，
  // 我们直接返回简化版的处理器
  // 真正的 audio_service 初始化在移动端执行
  
  // 初始化真正的 AudioService
  await AudioService.init(
    builder: () => _MobileAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ombhrum.fabushi.keep_alive',
      androidNotificationChannelName: '全球法布施',
      androidNotificationChannelDescription: '保持应用在后台运行，确保全球发送不中断',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidResumeOnClick: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      artDownscaleWidth: 300,
      artDownscaleHeight: 300,
    ),
  );
  
  // 返回我们的处理器包装
  return KeepAliveAudioHandler();
}

/// 移动端音频处理器（实现 audio_service 的 BaseAudioHandler）
class _MobileAudioHandler extends BaseAudioHandler with SeekHandler {
  @override
  Future<void> play() async {}
  
  @override
  Future<void> pause() async {}
  
  @override
  Future<void> stop() async {}
  
  @override
  Future<void> seek(Duration position) async {}
}
