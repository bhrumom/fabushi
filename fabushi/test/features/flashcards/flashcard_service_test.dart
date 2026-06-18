import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:global_dharma_sharing/features/flashcards/application/flashcard_service.dart';
import 'package:global_dharma_sharing/features/flashcards/data/flashcard_repository.dart';
import 'package:global_dharma_sharing/features/flashcards/domain/flashcard_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('random cloze generation creates persisted cloze cards', () async {
    final repository = FlashcardRepository();
    final service = FlashcardService(repository: repository);

    final deck = await service.generateRandomCloze(
      const FlashcardInput(
        title: '金刚经第五品',
        text:
            '如是我闻，一时，佛在舍卫国祇树给孤独园。与大比丘众千二百五十人俱。'
            '尔时，世尊食时，著衣持钵，入舍卫大城乞食。于其城中，次第乞已，还至本处。',
        maxCards: 10,
      ),
    );

    expect(deck.mode, FlashcardCreationMode.randomCloze);
    expect(deck.cards, isNotEmpty);
    expect(deck.cards.length, lessThanOrEqualTo(10));
    for (final card in deck.cards) {
      expect(card.cardType, FlashcardType.cloze);
      expect(card.clozeText, contains('＿'));
      expect(card.answer.trim(), isNotEmpty);
      expect(card.sourceQuote.trim(), isNotEmpty);
    }

    final savedDeck = await repository.getDeck(deck.id);
    expect(savedDeck, isNotNull);
    expect(savedDeck!.cards.length, deck.cards.length);
  });

  test('splitSentences filters short fragments and keeps useful sentences', () {
    final sentences = FlashcardService.splitSentences(
      '短。第一段包含足够多的文字用于生成背诵卡片。Second useful sentence works too!',
    );

    expect(sentences.length, 2);
    expect(sentences.first, contains('第一段'));
    expect(sentences.last, contains('Second'));
  });
}
