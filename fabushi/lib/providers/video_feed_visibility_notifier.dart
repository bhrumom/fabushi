import 'package:flutter/foundation.dart';

/// 管理视频流页面可见性状态的Notifier
/// 
/// 用于跟踪用户当前是否在法流页面上，
/// 以便TTS组件知道是否应该播放
class VideoFeedVisibilityNotifier extends ChangeNotifier {
  bool _isVideoFeedVisible = false;
  
  /// 法流页面是否可见
  bool get isVideoFeedVisible => _isVideoFeedVisible;
  
  /// 设置法流页面可见性
  void setVisible(bool visible) {
    if (_isVideoFeedVisible != visible) {
      _isVideoFeedVisible = visible;
      debugPrint('📱 VideoFeedVisibility: ${visible ? "VISIBLE" : "HIDDEN"}');
      notifyListeners();
    }
  }
}
