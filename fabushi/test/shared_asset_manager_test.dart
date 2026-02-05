import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/shared_asset_manager.dart';

void main() {
  group('SharedAssetManager', () {
    late SharedAssetManager assetManager;

    setUp(() {
      assetManager = SharedAssetManager();
    });

    test('应该是单例模式', () {
      final instance1 = SharedAssetManager();
      final instance2 = SharedAssetManager();
      expect(identical(instance1, instance2), true);
    });

    test('初始化后可以检查素材状态', () async {
      await assetManager.initialize();
      
      // 测试路径
      const testPath = 'assets/built_in/texts/心经.txt';
      
      // 初始状态应该是未下载
      final isDownloaded = assetManager.isAssetDownloaded(testPath);
      expect(isDownloaded, isA<bool>());
    });

    test('批量获取素材应该返回Map', () async {
      await assetManager.initialize();
      
      final paths = [
        'assets/built_in/texts/心经.txt',
        'assets/built_in/texts/金刚经.txt',
      ];
      
      final result = await assetManager.getAssets(paths);
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result.length, equals(2));
    });
  });
}
