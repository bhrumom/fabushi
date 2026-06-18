import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:global_dharma_sharing/features/flashcards/application/content_pipeline.dart';
import 'package:global_dharma_sharing/features/flashcards/data/flashcard_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('prepare returns preview content for short text', () async {
    final pipeline = ContentPipeline(repository: FlashcardRepository());

    final content = await pipeline.prepare(
      const ContentInput(
        title: '短正文',
        text: '愿以此功德，普及于一切。我等与众生，皆共成佛道。',
        sourceType: 'composer_text',
      ),
    );

    expect(content.isFailed, isFalse);
    expect(content.document, isNull);
    expect(content.title, '短正文');
    expect(content.previewText, contains('愿以此功德'));
  });

  test('prepare documentizes long text with configured threshold', () async {
    final pipeline = ContentPipeline(
      repository: FlashcardRepository(),
      textLongThresholdChars: 80,
    );
    final text = List.filled(8, '菩萨应如是降伏其心，离一切相，修一切善法，令众生得安稳。').join('');

    final content = await pipeline.prepare(
      ContentInput(title: '长正文', text: text, sourceType: 'composer_text'),
    );

    expect(content.isFailed, isFalse);
    expect(content.isLong, isTrue);
    expect(content.document, isNotNull);
    expect(content.document!.charCount, text.runes.length);
    expect(content.previewText.length, lessThan(text.length));
  });

  test('firstHttpUrl extracts the first usable link', () {
    final url = ContentPipeline.firstHttpUrl(
      '请看 https://example.com/articles/1，后面是说明',
    );
    expect(url, 'https://example.com/articles/1');
  });
}
