import 'package:flutter/foundation.dart';

/// Platform helpers for the shared Mahayana/Codex backend.
///
/// Product features use the shared Rust Runtime when available and the
/// first-party cloud API elsewhere.
class AiBackendPolicy {
  AiBackendPolicy._();

  @visibleForTesting
  static bool? debugIsDesktopNativeOverride;

  static bool get isDesktopNative {
    final debugOverride = debugIsDesktopNativeOverride;
    if (debugOverride != null) return debugOverride;
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  static Future<String> activeBackendLabel({bool isMember = false}) async {
    return isDesktopNative ? 'Mahayana Runtime' : '云端 API';
  }
}
