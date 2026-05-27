import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/core/config/app_config.dart';

void main() {
  group('Buddha model remote configuration', () {
    test('keeps the native .model on the R2 remote path', () {
      expect(AppConfig.buddhaModelAssetPath, 'models/buddha_model.model');
    });

    test('keeps native packages on cloud-only Buddha model loading', () {
      expect(AppConfig.buddhaModelAssetPath, startsWith('models/'));
      expect(AppConfig.buddhaModelAssetPath, endsWith('.model'));
      expect(
        AppConfig.minBuddhaModelSizeBytes,
        greaterThanOrEqualTo(100 * 1024 * 1024),
      );
    });

    test('does not package an Android GLB fallback', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, isNot(contains('.glb')));
      expect(pubspec, isNot(contains('web/assets/models/')));
    });
  });
}
