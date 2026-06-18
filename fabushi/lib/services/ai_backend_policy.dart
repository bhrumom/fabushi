import 'package:flutter/foundation.dart';

import 'app_settings.dart';

/// AI 后端选择策略。
///
/// 目标：业务 UI 不关心桌面/移动差异，首页仍然调用 DachengAiService。
/// - 桌面端默认走 App 内置 OpenClaw Gateway；
/// - Android / iOS / Web 默认继续走线上 API；
/// - 设置页可手动切换，便于排障和灰度。
enum AiBackendMode { auto, embeddedOpenClaw, cloudApi }

extension AiBackendModeX on AiBackendMode {
  String get storageName {
    switch (this) {
      case AiBackendMode.auto:
        return 'auto';
      case AiBackendMode.embeddedOpenClaw:
        return 'embedded_openclaw';
      case AiBackendMode.cloudApi:
        return 'cloud_api';
    }
  }

  String get label {
    switch (this) {
      case AiBackendMode.auto:
        return '自动';
      case AiBackendMode.embeddedOpenClaw:
        return '本机 OpenClaw';
      case AiBackendMode.cloudApi:
        return '云端 API';
    }
  }

  String get description {
    switch (this) {
      case AiBackendMode.auto:
        return '桌面端使用内置 OpenClaw，移动端使用云端 API';
      case AiBackendMode.embeddedOpenClaw:
        return '强制使用随 App 打包的本机 OpenClaw Gateway';
      case AiBackendMode.cloudApi:
        return '跳过本机 OpenClaw，直接使用现有大乘 AI API';
    }
  }
}

AiBackendMode aiBackendModeFromStorageName(String? value) {
  for (final mode in AiBackendMode.values) {
    if (mode.storageName == value) return mode;
  }
  return AiBackendMode.auto;
}

class AiBackendPolicy {
  AiBackendPolicy._();

  static bool get isDesktopNative {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  static Future<AiBackendMode> loadMode() async {
    final name = await AppSettings.getAiBackendModeName();
    return aiBackendModeFromStorageName(name);
  }

  static Future<bool> shouldUseEmbeddedOpenClaw() async {
    if (!isDesktopNative) return false;

    final mode = await loadMode();
    switch (mode) {
      case AiBackendMode.auto:
      case AiBackendMode.embeddedOpenClaw:
        return true;
      case AiBackendMode.cloudApi:
        return false;
    }
  }

  static Future<String> activeBackendLabel() async {
    if (!isDesktopNative) return '云端 API';
    final mode = await loadMode();
    if (mode == AiBackendMode.cloudApi) return '云端 API';
    return '本机 OpenClaw';
  }
}
