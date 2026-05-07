import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/app_version_service.dart';

void main() {
  group('AppVersionService.formatReportVersion', () {
    test('formats current release as display version with build number', () {
      expect(
        AppVersionService.formatReportVersion(
          version: '1.0.0',
          buildNumber: '58',
        ),
        '1.00(58)',
      );
    });

    test('keeps following CI build numbers dynamic', () {
      expect(
        AppVersionService.formatReportVersion(
          version: '1.0.0',
          buildNumber: '59',
        ),
        '1.00(59)',
      );
    });

    test('uses build metadata when explicit build number is absent', () {
      expect(
        AppVersionService.formatReportVersion(version: '1.0.0+58'),
        '1.00(58)',
      );
    });

    test('keeps non-zero patch versions visible', () {
      expect(
        AppVersionService.formatReportVersion(
          version: '1.2.3',
          buildNumber: '7',
        ),
        '1.2.3(7)',
      );
    });
  });
}
