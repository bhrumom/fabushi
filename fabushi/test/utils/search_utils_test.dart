import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/utils/search_utils.dart';

void main() {
  group('SearchUtils Tests', () {
    test('normalize converts arabic numbers to chinese', () {
      expect(SearchUtils.normalize('31'), '三十一');
      expect(SearchUtils.normalize('10'), '十');
      expect(SearchUtils.normalize('15'), '十五');
      expect(SearchUtils.normalize('5'), '五');
      expect(SearchUtils.normalize('华严经31卷'), '华严经三十一卷');
    });

    test('fuzzyMatch handles exact match', () {
      expect(SearchUtils.fuzzyMatch('大方广佛华严经', '华严经'), true);
      expect(SearchUtils.fuzzyMatch('大方广佛华严经', '金刚经'), false);
    });

    test('fuzzyMatch handles number conversion', () {
      expect(SearchUtils.fuzzyMatch('第三十一卷', '31'), true);
      expect(SearchUtils.fuzzyMatch('第三十一卷', '32'), false);
    });

    test('fuzzyMatch handles mixed content and numbers', () {
      expect(SearchUtils.fuzzyMatch('大方广佛华严经第三十一卷', '华严经31'), true);
      expect(SearchUtils.fuzzyMatch('大方广佛华严经第三十一卷', '华严31'), true);
      expect(SearchUtils.fuzzyMatch('大方广佛华严经第三十一卷', '华严经32'), false);
    });

    test('fuzzyMatch handles subsequence', () {
      // "华严经31" -> match "大方广佛华严经(部分)...第三十一卷"
      // Note: normalize('华严经31') -> '华严经三十一'
      // text has '华'...'严'...'经'...'三'...'十'...'一' in order
      expect(SearchUtils.fuzzyMatch('大方广佛华严经八十卷（第三十一卷）', '华严经31卷'), true);

      // Broken sequence
      expect(SearchUtils.fuzzyMatch('大方广佛华严经', '严华'), false);
    });
  });
}
