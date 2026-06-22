import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/openclaw/openclaw_ai_bridge.dart';

void main() {
  group('OpenClawAiBridge local tool intent', () {
    late OpenClawAiBridge bridge;

    setUp(() {
      bridge = OpenClawAiBridge();
    });

    test('detects browser and click requests', () {
      expect(
        bridge.requiresLocalToolExecutionForTest(
          'Open https://example.com in a browser and click the center.',
        ),
        isTrue,
      );
      expect(bridge.requiresLocalToolExecutionForTest('打开浏览器访问网页'), isTrue);
      expect(
        bridge.requiresLocalToolExecutionForTest('请点击页面中央，然后回复完成'),
        isTrue,
      );
    });

    test('does not classify ordinary chat as local tool execution', () {
      expect(bridge.requiresLocalToolExecutionForTest('解释一下心经的核心意思'), isFalse);
      expect(
        bridge.requiresLocalToolExecutionForTest('Summarize this paragraph.'),
        isFalse,
      );
    });
  });
}
