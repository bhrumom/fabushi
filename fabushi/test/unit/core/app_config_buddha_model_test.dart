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
  });
}
