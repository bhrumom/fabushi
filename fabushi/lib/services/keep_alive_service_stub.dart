import 'keep_alive_service.dart';

/// Stub implementation for non-mobile platforms (Windows, macOS, Linux, Web)
/// AudioService is not supported on these platforms
Future<KeepAliveAudioHandler> initializeAudioService() async {
  // Simply return a local audio handler without system media integration
  return KeepAliveAudioHandler();
}
