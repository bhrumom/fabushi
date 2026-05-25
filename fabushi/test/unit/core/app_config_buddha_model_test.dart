import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/core/config/app_config.dart';

void main() {
  group('Buddha model configuration', () {
    test('uses the flutter_scene .model R2 object only', () {
      expect(AppConfig.buddhaModelAssetPath, 'models/buddha_model.model');
      expect(AppConfig.buddhaModelAssetPath, endsWith('.model'));
      expect(AppConfig.minBuddhaModelSizeBytes, 100 * 1024 * 1024);
    });
  });
}
