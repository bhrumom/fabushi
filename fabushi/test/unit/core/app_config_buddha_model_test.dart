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

    test('packages the Android WebView fallback assets explicitly', () {
      expect(
        AppConfig.bundledBuddhaFallbackHtmlAssetPath,
        'assets/buddha_fallback/index.html',
      );
      expect(AppConfig.bundledBuddhaGlbAssetPath, 'web/assets/models/佛像模型.glb');
    });

    test('keeps the bundled Android fallback self-contained', () {
      final fallbackHtml = File(AppConfig.bundledBuddhaFallbackHtmlAssetPath);
      final fallbackScript = File('assets/buddha_fallback/buddha_fallback.js');
      final fallbackGlb = File(AppConfig.bundledBuddhaGlbAssetPath);

      expect(fallbackHtml.existsSync(), isTrue);
      expect(fallbackScript.existsSync(), isTrue);
      expect(fallbackGlb.existsSync(), isTrue);

      final html = fallbackHtml.readAsStringSync();
      expect(html, contains('buddha_fallback.js'));
      expect(html, isNot(contains('cdn.jsdelivr.net')));
      expect(html, isNot(contains('esm.sh')));
    });

    test('prefers bundled GLB candidates before the remote static URL', () {
      final html = File(AppConfig.bundledBuddhaFallbackHtmlAssetPath)
          .readAsStringSync();

      expect(html, contains('bundled-glb-relative-two-up'));
      expect(html, contains('bundled-glb-relative-one-up'));
      expect(html, contains('bundled-glb-origin-assets-root'));
      expect(html, contains('bundled-glb-origin-web-root'));
      expect(html.indexOf('bundled-glb-relative-two-up'), isNonNegative);
      expect(html.indexOf('remote-static-glb'), isNonNegative);
      expect(
        html.indexOf('bundled-glb-relative-two-up'),
        lessThan(html.indexOf('remote-static-glb')),
      );
    });
  });
}
