import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants/app_constants.dart';

class AppBuildInfo {
  const AppBuildInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String version;
  final String buildNumber;

  String get versionLabel {
    final normalizedVersion = version.trim();
    final normalizedBuildNumber = buildNumber.trim();

    if (normalizedVersion.isEmpty) {
      return normalizedBuildNumber.isEmpty
          ? AppConstants.appVersion
          : normalizedBuildNumber;
    }

    if (normalizedBuildNumber.isEmpty ||
        normalizedVersion.endsWith('+$normalizedBuildNumber')) {
      return normalizedVersion;
    }

    return '$normalizedVersion+$normalizedBuildNumber';
  }
}

class AppBuildInfoService {
  AppBuildInfoService._();

  static final AppBuildInfoService instance = AppBuildInfoService._();

  AppBuildInfo? _cachedInfo;

  Future<AppBuildInfo> getBuildInfo() async {
    final cachedInfo = _cachedInfo;
    if (cachedInfo != null) {
      return cachedInfo;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildInfo = AppBuildInfo(
        appName: packageInfo.appName.trim().isEmpty
            ? AppConstants.appName
            : packageInfo.appName.trim(),
        version: packageInfo.version.trim(),
        buildNumber: packageInfo.buildNumber.trim(),
      );
      _cachedInfo = buildInfo;
      return buildInfo;
    } catch (error) {
      debugPrint('读取应用构建信息失败，回退到静态版本号: $error');
      final fallbackInfo = _fallbackBuildInfo();
      _cachedInfo = fallbackInfo;
      return fallbackInfo;
    }
  }

  Future<String> getVersionLabel() async {
    return (await getBuildInfo()).versionLabel;
  }

  AppBuildInfo _fallbackBuildInfo() {
    final rawVersion = AppConstants.appVersion.trim();
    final separatorIndex = rawVersion.lastIndexOf('+');

    if (separatorIndex <= 0 || separatorIndex == rawVersion.length - 1) {
      return AppBuildInfo(
        appName: AppConstants.appName,
        version: rawVersion,
        buildNumber: '',
      );
    }

    return AppBuildInfo(
      appName: AppConstants.appName,
      version: rawVersion.substring(0, separatorIndex),
      buildNumber: rawVersion.substring(separatorIndex + 1),
    );
  }
}
