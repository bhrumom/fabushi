import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/content_filter_service.dart';

void main() {
  group('ContentFilterService', () {
    test('正常文本不触发过滤', () {
      expect(ContentFilterService.containsObjectionableContent('佛陀慈悲，法喜充满'), isFalse);
      expect(ContentFilterService.containsObjectionableContent('南无阿弥陀佛'), isFalse);
      expect(ContentFilterService.containsObjectionableContent(''), isFalse);
      expect(ContentFilterService.containsObjectionableContent(null), isFalse);
    });

    test('含违禁词文本触发过滤', () {
      expect(ContentFilterService.containsObjectionableContent('色情内容'), isTrue);
      expect(ContentFilterService.containsObjectionableContent('包含暴力的文字'), isTrue);
      expect(ContentFilterService.containsObjectionableContent('该用户在威胁别人'), isTrue);
    });

    test('英文违禁词也被检测到', () {
      expect(ContentFilterService.containsObjectionableContent('porn site'), isTrue);
      expect(ContentFilterService.containsObjectionableContent('racist remarks'), isTrue);
      expect(ContentFilterService.containsObjectionableContent('Normal Buddhist text'), isFalse);
    });

    test('大小写不敏感', () {
      expect(ContentFilterService.containsObjectionableContent('PORN content'), isTrue);
      expect(ContentFilterService.containsObjectionableContent('Violence here'), isTrue);
    });
  });
}
