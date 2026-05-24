import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/recitation_progress_matcher.dart';

void main() {
  group('RecitationProgressMatcher', () {
    test('counts repeated short mantra with cooldown protection', () {
      var now = DateTime(2026, 5, 24, 8);
      final matcher = RecitationProgressMatcher('南无阿弥陀佛', now: () => now);

      final first = matcher.accept('南无阿弥陀佛', isEndpoint: true);
      expect(first.countDelta, 1);
      expect(first.progress, 1);

      final duplicate = matcher.accept('南无阿弥陀佛', isEndpoint: true);
      expect(duplicate.countDelta, 0);

      now = now.add(const Duration(milliseconds: 1300));
      final second = matcher.accept('南无阿弥陀佛', isEndpoint: true);
      expect(second.countDelta, 1);
    });

    test('tracks long text progress and counts after completion', () {
      final sutra = List.filled(16, '观自在菩萨行深般若波罗蜜多时').join('，');
      final matcher = RecitationProgressMatcher(sutra);

      final firstHalf = matcher.accept(
        List.filled(8, '观自在菩萨行深般若波罗蜜多时').join('，'),
      );
      expect(firstHalf.countDelta, 0);
      expect(firstHalf.progress, greaterThan(0.40));
      expect(firstHalf.progress, lessThan(0.70));

      final secondHalf = matcher.accept(
        List.filled(8, '观自在菩萨行深般若波罗蜜多时').join('，'),
        isEndpoint: true,
      );
      expect(secondHalf.countDelta, 1);
      expect(secondHalf.progress, 1);
    });

    test('tolerates small recognition omissions through pinyin matching', () {
      final matcher = RecitationProgressMatcher('唵嘛呢叭咪吽');

      final event = matcher.accept('唵嘛呢巴咪吽', isEndpoint: true);
      expect(event.countDelta, 1);
      expect(event.progress, 1);
    });
  });
}
