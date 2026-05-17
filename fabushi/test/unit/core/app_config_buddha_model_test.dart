import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/core/config/app_config.dart';

void main() {
  group('Buddha model remote configuration', () {
    test('keeps the native .model on the R2 remote path', () {
      expect(AppConfig.buddhaModelAssetPath, 'models/buddha_model.model');
    });

    test('loads the compatibility GLB from the public remote static host', () {
      expect(
        AppConfig.legacyBuddhaGlbUrl,
        'https://flutter.ombhrum.com/assets/models/'
        '%E4%BD%9B%E5%83%8F%E6%A8%A1%E5%9E%8B.glb',
      );
      expect(AppConfig.legacyBuddhaGlbUrl, isNot(contains('/r2?file=')));
    });

    test('packages the Android three_dart GLB explicitly', () {
      expect(
        AppConfig.androidThreeBuddhaGlbAssetPath,
        'web/assets/models/佛像模型.glb',
      );
      expect(AppConfig.minBuddhaGlbSizeBytes, 10 * 1024 * 1024);
    });

    test('keeps the bundled Android GLB usable by three_dart', () {
      final fallbackGlb = File(AppConfig.androidThreeBuddhaGlbAssetPath);

      expect(fallbackGlb.existsSync(), isTrue);
      expect(
        fallbackGlb.lengthSync(),
        greaterThanOrEqualTo(AppConfig.minBuddhaGlbSizeBytes),
      );

      final header = fallbackGlb.openSync().readSync(4);
      expect(String.fromCharCodes(header), 'glTF');
    });
  });
}
