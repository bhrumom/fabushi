import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import 'api_client.dart';
import 'worker_config.dart';

class AppErrorReport {
  AppErrorReport({
    required this.errorText,
    required this.stackTraceText,
    required this.stage,
    required this.source,
    required this.platform,
    required this.appVersion,
    required this.occurredAt,
    required this.fatal,
    required this.deviceSummary,
    required this.extra,
  });

  final String errorText;
  final String stackTraceText;
  final String stage;
  final String source;
  final String platform;
  final String appVersion;
  final DateTime occurredAt;
  final bool fatal;
  final String deviceSummary;
  final Map<String, dynamic> extra;

  String get summary {
    final firstLine = errorText.split('\n').first.trim();
    if (firstLine.isEmpty) {
      return '应用运行异常';
    }
    return firstLine.length > 72 ? '${firstLine.substring(0, 72)}...' : firstLine;
  }

  String get suggestedTitle {
    return '启动异常: $summary';
  }

  Map<String, dynamic> toDiagnosticsPayload() {
    return {
      'stage': stage,
      'source': source,
      'fatal': fatal,
      'platform': platform,
      'appVersion': appVersion,
      'occurredAt': occurredAt.toIso8601String(),
      'deviceSummary': deviceSummary,
      'error': errorText,
      'stackTrace': stackTraceText,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }

  String buildFeedbackDescription(String userDescription) {
    final lines = <String>[
      '应用在启动过程中出现异常，以下信息由客户端自动采集。',
      '',
      if (userDescription.trim().isNotEmpty) ...[
        '### 用户补充说明',
        '',
        userDescription.trim(),
        '',
      ],
      '### 异常摘要',
      '',
      '- 阶段: $stage',
      '- 来源: $source',
      '- 平台: $platform',
      '- 版本: $appVersion',
      '- 时间: ${occurredAt.toIso8601String()}',
      '- 严重级别: ${fatal ? 'fatal' : 'non-fatal'}',
      '- 设备: $deviceSummary',
      '',
      '### 错误信息',
      '',
      '```',
      errorText,
      '```',
      '',
    ];

    if (stackTraceText.trim().isNotEmpty) {
      lines.addAll([
        '### 堆栈信息',
        '',
        '```',
        stackTraceText,
        '```',
        '',
      ]);
    }

    if (extra.isNotEmpty) {
      lines.addAll([
        '### 附加上下文',
        '',
        '```json',
        const JsonEncoder.withIndent('  ').convert(extra),
        '```',
      ]);
    }

    return lines.join('\n').trim();
  }
}

class ErrorReportService {
  ErrorReportService._();

  static final ErrorReportService instance = ErrorReportService._();

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  AppErrorReport? _lastReport;
  bool _globalHandlersInstalled = false;

  AppErrorReport? get lastReport => _lastReport;

  Future<void> initializeGlobalHandlers() async {
    if (_globalHandlersInstalled) {
      return;
    }

    final previousOnError = FlutterError.onError;

    FlutterError.onError = (details) {
      previousOnError?.call(details);
      unawaited(
        recordError(
          details.exception,
          stackTrace: details.stack,
          stage: 'flutter_framework',
          source: 'FlutterError.onError',
          fatal: true,
          extra: {
            if (details.context != null)
              'context': details.context?.toDescription(),
            if (details.library != null) 'library': details.library,
          },
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        recordError(
          error,
          stackTrace: stackTrace,
          stage: 'platform_dispatcher',
          source: 'PlatformDispatcher.onError',
          fatal: true,
        ),
      );
      return false;
    };

    _globalHandlersInstalled = true;
  }

  Future<AppErrorReport> recordError(
    Object error, {
    StackTrace? stackTrace,
    required String stage,
    required String source,
    bool fatal = false,
    Map<String, dynamic>? extra,
  }) async {
    final report = AppErrorReport(
      errorText: error.toString(),
      stackTraceText: stackTrace?.toString() ?? '',
      stage: stage,
      source: source,
      platform: _platformLabel(),
      appVersion: AppConstants.appVersion,
      occurredAt: DateTime.now().toUtc(),
      fatal: fatal,
      deviceSummary: await _collectDeviceSummary(),
      extra: extra ?? <String, dynamic>{},
    );

    _lastReport = report;
    debugPrint('🧯 ErrorReportService captured error: ${report.summary}');
    return report;
  }

  Future<Map<String, dynamic>> submitLastReport({
    required String title,
    required String userDescription,
    required String contact,
    String? authToken,
  }) async {
    final report = _lastReport;
    if (report == null) {
      return {
        'success': false,
        'error': '当前没有可提交的错误报告。',
      };
    }

    return ApiClient.instance.post(
      WorkerConfig.getEndpoint('submitFeedback'),
      body: {
        'title': title.trim().isEmpty ? report.suggestedTitle : title.trim(),
        'description': report.buildFeedbackDescription(userDescription),
        if (contact.trim().isNotEmpty) 'contact': contact.trim(),
        'page': 'startup_failure_dialog',
        'platform': report.platform,
        'appVersion': report.appVersion,
        'category': 'startup_crash',
        'autoCollected': true,
        'diagnostics': report.toDiagnosticsPayload(),
      },
      token: authToken,
    );
  }

  String _platformLabel() {
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
        return 'fuchsia';
    }
  }

  Future<String> _collectDeviceSummary() async {
    try {
      if (kIsWeb) {
        final info = await _deviceInfoPlugin.webBrowserInfo;
        return '${info.browserName.name} on ${info.platform ?? 'web'}';
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _deviceInfoPlugin.androidInfo;
          return '${info.brand} ${info.model} (Android ${info.version.release}, SDK ${info.version.sdkInt})';
        case TargetPlatform.iOS:
          final info = await _deviceInfoPlugin.iosInfo;
          return '${info.name} ${info.model} (iOS ${info.systemVersion})';
        case TargetPlatform.macOS:
          final info = await _deviceInfoPlugin.macOsInfo;
          return '${info.model} (macOS ${info.osRelease})';
        case TargetPlatform.windows:
          final info = await _deviceInfoPlugin.windowsInfo;
          return '${info.productName} ${info.displayVersion}';
        case TargetPlatform.linux:
          final info = await _deviceInfoPlugin.linuxInfo;
          return '${info.name} ${info.version ?? ''}'.trim();
        case TargetPlatform.fuchsia:
          return 'fuchsia';
      }
    } catch (error) {
      debugPrint('采集设备信息失败: $error');
      return 'unknown device';
    }
  }
}
