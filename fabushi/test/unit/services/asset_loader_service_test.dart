import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/asset_loader_service.dart';

void main() {
  group('AssetLoaderService Buddha model validation', () {
    test('accepts flutter_scene .model data with IPSC file identifier', () {
      final data = Uint8List.fromList([
        0x14,
        0x00,
        0x00,
        0x00,
        0x49,
        0x50,
        0x53,
        0x43,
      ]);

      expect(AssetLoaderService.isFlutterSceneModelData(data), isTrue);
    });

    test('rejects GLB or truncated data as .model bytes', () {
      final glb = Uint8List.fromList([
        0x67,
        0x6C,
        0x54,
        0x46,
        0x02,
        0x00,
        0x00,
        0x00,
      ]);

      expect(AssetLoaderService.isFlutterSceneModelData(glb), isFalse);
      expect(AssetLoaderService.isFlutterSceneModelData(Uint8List(4)), isFalse);
    });
  });
}
