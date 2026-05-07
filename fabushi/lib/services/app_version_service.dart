import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  AppVersionService._();

  static Future<String> currentReportVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return formatReportVersion(
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
    } catch (_) {
      return 'unknown';
    }
  }

  static String formatReportVersion({
    required String version,
    String? buildNumber,
  }) {
    final parts = version.split('+');
    final versionName = parts.first.trim();
    final resolvedBuild = (buildNumber?.trim().isNotEmpty ?? false)
        ? buildNumber!.trim()
        : (parts.length > 1 ? parts.sublist(1).join('+').trim() : '');
    final formattedName = _formatVersionName(versionName);

    if (resolvedBuild.isEmpty) {
      return formattedName;
    }
    return '$formattedName($resolvedBuild)';
  }

  static String _formatVersionName(String versionName) {
    final segments = versionName
        .split('.')
        .map((segment) => int.tryParse(segment.trim()))
        .toList();
    if (segments.length >= 3 &&
        segments[0] != null &&
        segments[1] != null &&
        segments[2] == 0) {
      return '${segments[0]}.${segments[1]!.toString().padLeft(2, '0')}';
    }
    return versionName;
  }
}
