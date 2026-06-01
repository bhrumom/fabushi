import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/widgets/scene_render_mode.dart';

void main() {
  group('SceneRenderAccess', () {
    test('keeps 3D locked for non-members', () {
      expect(
        SceneRenderAccess.canUseThreeD(hasPremiumAccess: false, isAdmin: false),
        isFalse,
      );
    });

    test('allows 3D for effective members', () {
      expect(
        SceneRenderAccess.canUseThreeD(hasPremiumAccess: true, isAdmin: false),
        isTrue,
      );
    });

    test('allows 3D for admins', () {
      expect(
        SceneRenderAccess.canUseThreeD(hasPremiumAccess: false, isAdmin: true),
        isTrue,
      );
    });
  });
}
