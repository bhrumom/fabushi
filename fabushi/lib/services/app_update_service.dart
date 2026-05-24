import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import 'http_service.dart';

enum AppUpdateMode { optional, force }

class AppVersionPolicy {
  AppVersionPolicy({
    required this.enabled,
    required this.platform,
    required this.channel,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minSupportedBuildNumber,
    required this.forceUpdate,
    required this.allowSkip,
    required this.rolloutPercentage,
    required this.promptIntervalHours,
    required this.title,
    required this.message,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.updateAvailable,
    required this.strategy,
    this.publishedAt,
  });

  final bool enabled;
  final String platform;
  final String channel;
  final String latestVersion;
  final int latestBuildNumber;
  final int minSupportedBuildNumber;
  final bool forceUpdate;
  final bool allowSkip;
  final int rolloutPercentage;
  final int promptIntervalHours;
  final String title;
  final String message;
  final String downloadUrl;
  final List<String> releaseNotes;
  final bool updateAvailable;
  final String strategy;
  final DateTime? publishedAt;

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    final releaseNotesRaw = json['releaseNotes'];
    final releaseNotes = releaseNotesRaw is List
        ? releaseNotesRaw
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    return AppVersionPolicy(
      enabled: json['enabled'] != false,
      platform: (json['platform'] ?? 'unknown').toString(),
      channel: (json['channel'] ?? 'stable').toString(),
      latestVersion: (json['latestVersion'] ?? AppConfig.appVersion).toString(),
      latestBuildNumber: _parseInt(
        json['latestBuildNumber'],
        AppConfig.appBuildNumber,
      ),
      minSupportedBuildNumber: _parseInt(
        json['minSupportedBuildNumber'],
        AppConfig.appBuildNumber,
      ),
      forceUpdate: json['forceUpdate'] == true,
      allowSkip: json['allowSkip'] != false,
      rolloutPercentage: _parseInt(json['rolloutPercentage'], 100)
          .clamp(0, 100)
          .toInt(),
      promptIntervalHours: _parseInt(json['promptIntervalHours'], 24),
      title: (json['title'] ?? '发现新版本').toString(),
      message: (json['message'] ?? '新版本已发布，建议尽快更新。').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      releaseNotes: releaseNotes,
      updateAvailable: json['updateAvailable'] == true,
      strategy: (json['strategy'] ?? 'none').toString(),
      publishedAt: DateTime.tryParse((json['publishedAt'] ?? '').toString()),
    );
  }

  static int _parseInt(dynamic value, int fallbackValue) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallbackValue;
  }
}

class AppUpdateDecision {
  AppUpdateDecision({
    required this.mode,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.policy,
  });

  final AppUpdateMode mode;
  final String currentVersion;
  final int currentBuildNumber;
  final AppVersionPolicy policy;

  bool get isForce => mode == AppUpdateMode.force;
  bool get canSkip => !isForce && policy.allowSkip;
  String get latestVersionLabel =>
      '${policy.latestVersion} (${policy.latestBuildNumber})';
}

class _AppInstallationInfo {
  _AppInstallationInfo({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.channel,
  });

  final String version;
  final int buildNumber;
  final String platform;
  final String channel;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const String _installIdKey = 'app_update_install_id';
  static const String _skippedBuildNumberKey = 'app_update_skipped_build_number';
  static const String _lastPromptAtKey = 'app_update_last_prompt_at';
  static final Uuid _uuid = Uuid();

  Future<AppUpdateDecision?> checkForUpdate({
    bool ignoreLocalGuards = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = await _getOrCreateInstallId(prefs);
      final info = await _getInstallationInfo();

      final response = await HttpService.get(
        AppConfig.appVersionPolicyUrl,
        queryParams: {
          'platform': info.platform,
          'channel': info.channel,
          'version': info.version,
          'buildNumber': info.buildNumber.toString(),
          'installId': installId,
        },
      );

      if (!HttpService.isSuccessResponse(response)) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final policy = AppVersionPolicy.fromJson(payload);
      if (!policy.enabled || !policy.updateAvailable) {
        return null;
      }

      if (!_isRolloutEligible(installId, policy.rolloutPercentage)) {
        return null;
      }

      final hasNewerBuild = info.buildNumber < policy.latestBuildNumber;
      final hasNewerVersion =
          _compareVersions(info.version, policy.latestVersion) < 0;
      if (!hasNewerBuild && !hasNewerVersion) {
        return null;
      }

      final isForce = policy.forceUpdate ||
          info.buildNumber < policy.minSupportedBuildNumber;
      final decision = AppUpdateDecision(
        mode: isForce ? AppUpdateMode.force : AppUpdateMode.optional,
        currentVersion: info.version,
        currentBuildNumber: info.buildNumber,
        policy: policy,
      );

      if (isForce) {
        await clearSkippedVersion();
        return decision;
      }

      if (!ignoreLocalGuards) {
        final skippedBuildNumber = prefs.getInt(_skippedBuildNumberKey);
        if (skippedBuildNumber == policy.latestBuildNumber) {
          return null;
        }

        final lastPromptAtMillis = prefs.getInt(_lastPromptAtKey);
        if (lastPromptAtMillis != null) {
          final lastPromptAt = DateTime.fromMillisecondsSinceEpoch(
            lastPromptAtMillis,
          );
          final nextPromptAt = lastPromptAt.add(
            Duration(hours: policy.promptIntervalHours),
          );
          if (DateTime.now().isBefore(nextPromptAt)) {
            return null;
          }
        }
      }

      return decision;
    } catch (error) {
      debugPrint('版本策略检查失败: $error');
      return null;
    }
  }

  Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPromptAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> markSkippedVersion(AppUpdateDecision decision) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _skippedBuildNumberKey,
      decision.policy.latestBuildNumber,
    );
  }

  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skippedBuildNumberKey);
  }

  Future<bool> openUpdatePage(AppUpdateDecision decision) async {
    final updateUrl = decision.policy.downloadUrl.trim();
    if (updateUrl.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(updateUrl);
    if (uri == null) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<_AppInstallationInfo> _getInstallationInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = int.tryParse(packageInfo.buildNumber) ??
          AppConfig.appBuildNumber;
      final version = packageInfo.version.isNotEmpty
          ? packageInfo.version
          : AppConfig.appVersion;
      return _AppInstallationInfo(
        version: version,
        buildNumber: buildNumber,
        platform: _resolvePlatform(),
        channel: _resolveChannel(),
      );
    } catch (_) {
      return _AppInstallationInfo(
        version: AppConfig.appVersion,
        buildNumber: AppConfig.appBuildNumber,
        platform: _resolvePlatform(),
        channel: _resolveChannel(),
      );
    }
  }

  Future<String> _getOrCreateInstallId(SharedPreferences prefs) async {
    final existing = prefs.getString(_installIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    await prefs.setString(_installIdKey, created);
    return created;
  }

  String _resolvePlatform() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }

  String _resolveChannel() {
    if (AppConfig.isProduction) {
      return 'stable';
    }
    if (AppConfig.isStaging) {
      return 'staging';
    }
    return 'development';
  }

  bool _isRolloutEligible(String installId, int rolloutPercentage) {
    if (rolloutPercentage >= 100) {
      return true;
    }
    if (rolloutPercentage <= 0) {
      return false;
    }

    var hash = 0;
    for (final codeUnit in installId.codeUnits) {
      hash = (hash * 31 + codeUnit) % 100;
    }
    return hash < rolloutPercentage;
  }

  int _compareVersions(String left, String right) {
    final leftParts = left
        .split('.')
        .map((item) => int.tryParse(item) ?? 0)
        .toList(growable: false);
    final rightParts = right
        .split('.')
        .map((item) => int.tryParse(item) ?? 0)
        .toList(growable: false);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < length; index += 1) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue > rightValue) {
        return 1;
      }
      if (leftValue < rightValue) {
        return -1;
      }
    }
    return 0;
  }
}
