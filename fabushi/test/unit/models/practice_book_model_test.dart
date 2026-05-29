import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/practice_book_model.dart';

void main() {
  group('PracticeBook', () {
    test('defaults to local only storage', () {
      final book = PracticeBook.create(
        id: 'book-1',
        practiceTitle: 'Daily practice',
        title: 'Manual chanting text',
        sourceType: PracticeBookSourceType.manual,
        plainText: 'Namo Amitabha',
      );

      expect(book.syncStatus, PracticeBookSyncStatus.localOnly);
      expect(book.remoteObjectKey, isNull);
    });

    test('can clear stale remote object references', () {
      final book = PracticeBook.create(
        id: 'book-2',
        practiceTitle: 'Heart Sutra',
        title: 'Heart Sutra practice',
        sourceType: PracticeBookSourceType.url,
        sourceUrl: 'https://example.com/heart-sutra',
        plainText: 'https://example.com/heart-sutra',
        remoteObjectKey: 'practice-books/book-2.txt',
        syncStatus: PracticeBookSyncStatus.synced,
      );

      final localBook = book.copyWith(
        syncStatus: PracticeBookSyncStatus.localOnly,
        remoteObjectKey: null,
      );

      expect(localBook.syncStatus, PracticeBookSyncStatus.localOnly);
      expect(localBook.remoteObjectKey, isNull);
      expect(localBook.sourceUrl, 'https://example.com/heart-sutra');
    });
  });
}
