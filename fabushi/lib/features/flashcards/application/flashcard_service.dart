import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../services/dacheng_ai_service.dart';
import '../data/flashcard_repository.dart';
import '../domain/flashcard_models.dart';

class FlashcardInput {
  final String title;
  final String text;
  final String? documentId;
  final String? sourceUrl;
  final String requirement;
  final int maxCards;

  const FlashcardInput({
    required this.title,
    required this.text,
    this.documentId,
    this.sourceUrl,
    this.requirement = '',
    this.maxCards = 80,
  });
}

enum FlashcardGenerationEventType { progress, cardDelta, done, error, stopped }

class FlashcardGenerationEvent {
  final FlashcardGenerationEventType type;
  final String message;
  final int progress;
  final Flashcard? card;
  final FlashcardDeck? deck;

  const FlashcardGenerationEvent({
    required this.type,
    required this.message,
    this.progress = 0,
    this.card,
    this.deck,
  });

  bool get isDone => type == FlashcardGenerationEventType.done;
  bool get isError => type == FlashcardGenerationEventType.error;
}

class FlashcardService {
  FlashcardService({
    FlashcardRepository? repository,
    DachengAiService? aiService,
  }) : _repository = repository ?? FlashcardRepository(),
       _aiService = aiService ?? DachengAiService();

  static const int defaultMaxCards = 80;
  static const int randomBlankMinGap = 3;

  final FlashcardRepository _repository;
  final DachengAiService _aiService;

  Future<FlashcardDeck> generateRandomCloze(FlashcardInput input) async {
    final now = DateTime.now();
    final deckId = flashcardId('deck');
    final sentences = splitSentences(input.text);
    final cards = <Flashcard>[];
    var sentenceIndex = 0;

    for (final sentence in sentences) {
      for (final part in splitLongSentence(sentence)) {
        if (cards.length >= min(input.maxCards, defaultMaxCards)) break;
        final card = _buildClozeCard(
          deckId: deckId,
          sentence: part,
          sentenceIndex: sentenceIndex,
          orderIndex: cards.length,
        );
        if (card != null) cards.add(card);
      }
      sentenceIndex++;
      if (cards.length >= min(input.maxCards, defaultMaxCards)) break;
    }

    if (cards.isEmpty) {
      throw StateError('CONTENT_TOO_SHORT: 内容过短，请至少输入 20 个字或 2 句话。');
    }

    final deck = FlashcardDeck(
      id: deckId,
      title: normalizeTitle(input.title),
      sourceDocumentId: input.documentId,
      mode: FlashcardCreationMode.randomCloze,
      requirement: input.requirement,
      status: FlashcardDeckStatus.ready,
      cards: cards,
      generationLog: const ['清洗文本', '按句切分', '随机挖空', '校验答案'],
      createdAt: now,
      updatedAt: now,
    );
    return _repository.saveDeck(deck);
  }

  Stream<FlashcardGenerationEvent> generateRandomClozeStream(
    FlashcardInput input,
  ) async* {
    yield const FlashcardGenerationEvent(
      type: FlashcardGenerationEventType.progress,
      message: '正在提取正文并清洗多余空白...',
      progress: 15,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    yield const FlashcardGenerationEvent(
      type: FlashcardGenerationEventType.progress,
      message: '正在按标点切分句子...',
      progress: 35,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    yield const FlashcardGenerationEvent(
      type: FlashcardGenerationEventType.progress,
      message: '正在生成随机挖空卡片...',
      progress: 70,
    );
    try {
      final deck = await generateRandomCloze(input);
      for (final card in deck.cards.take(3)) {
        yield FlashcardGenerationEvent(
          type: FlashcardGenerationEventType.cardDelta,
          message: '已生成：${card.answer}',
          progress: 86,
          card: card,
        );
      }
      yield FlashcardGenerationEvent(
        type: FlashcardGenerationEventType.done,
        message: '随机挖空完成，共 ${deck.cardCount} 张卡片。',
        progress: 100,
        deck: deck,
      );
    } catch (e) {
      yield FlashcardGenerationEvent(
        type: FlashcardGenerationEventType.error,
        message: e.toString(),
      );
    }
  }

  Stream<FlashcardGenerationEvent> generateAiCardsStream(
    FlashcardInput input, {
    String? conversationId,
    String? token,
    String? username,
    bool isMember = false,
  }) async* {
    final prompt = buildAiPrompt(input);
    var finalText = '';
    final generatedCards = <Flashcard>[];

    yield const FlashcardGenerationEvent(
      type: FlashcardGenerationEventType.progress,
      message: '正在理解内容与制卡要求...',
      progress: 8,
    );

    try {
      await for (final event in _aiService.sendChatStream(
        message: prompt,
        conversationId: conversationId,
        token: token,
        username: username,
        isMember: isMember,
      )) {
        if (event.isStep) {
          final text = _visibleStep(event);
          if (text.isNotEmpty) {
            yield FlashcardGenerationEvent(
              type: FlashcardGenerationEventType.progress,
              message: text,
              progress: min(92, 18 + generatedCards.length * 5),
            );
          }
        } else if (event.isDelta) {
          finalText += event.text;
          final parsedDelta = _tryParseDeck(
            rawText: finalText,
            input: input,
            fallbackMode: FlashcardCreationMode.aiCards,
            persist: false,
          );
          if (parsedDelta != null &&
              parsedDelta.cards.length > generatedCards.length) {
            final newCards = parsedDelta.cards
                .skip(generatedCards.length)
                .take(3);
            generatedCards.addAll(newCards);
            for (final card in newCards) {
              yield FlashcardGenerationEvent(
                type: FlashcardGenerationEventType.cardDelta,
                message: '已生成卡片：${card.front}',
                progress: min(92, 22 + generatedCards.length * 6),
                card: card,
              );
            }
          }
        } else if (event.isDone) {
          finalText = (event.raw['message'] ?? finalText).toString();
        } else if (event.isError) {
          throw StateError(event.text.isEmpty ? 'AI 制卡失败' : event.text);
        }
      }

      final deck = await _parseAndSaveAiDeck(finalText, input);
      yield FlashcardGenerationEvent(
        type: FlashcardGenerationEventType.done,
        message: 'AI 制卡完成，共 ${deck.cardCount} 张卡片。',
        progress: 100,
        deck: deck,
      );
    } catch (e) {
      yield FlashcardGenerationEvent(
        type: FlashcardGenerationEventType.progress,
        message: 'AI 制卡失败，正在回退为本地随机挖空。原因：$e',
        progress: 88,
      );
      try {
        final deck = await generateRandomCloze(input);
        yield FlashcardGenerationEvent(
          type: FlashcardGenerationEventType.done,
          message: '已回退为随机挖空，共 ${deck.cardCount} 张卡片。',
          progress: 100,
          deck: deck,
        );
      } catch (fallbackError) {
        yield FlashcardGenerationEvent(
          type: FlashcardGenerationEventType.error,
          message: fallbackError.toString(),
        );
      }
    }
  }

  Future<FlashcardDeck> saveDeck(FlashcardDeck deck) {
    return _repository.saveDeck(deck);
  }

  Future<List<FlashcardDeck>> listDecks() => _repository.listDecks();

  static String buildAiPrompt(FlashcardInput input) {
    final requirement = input.requirement.trim().isEmpty
        ? '请提取核心概念，生成问答卡和挖空卡。'
        : input.requirement.trim();
    final content = input.text.length > 12000
        ? '${input.text.substring(0, 12000)}\n（内容已截断，请基于以上内容制卡）'
        : input.text;
    return '''你是法布施 App 的知识背诵闪卡生成器。
请根据正文和用户要求生成可背诵闪卡，只输出 JSON，不要输出 Markdown。

输出格式：
{
  "title": "卡组标题",
  "cards": [
    {
      "type": "qa 或 cloze",
      "front": "正面题目",
      "back": "背面解释或完整答案",
      "clozeText": "挖空文本，可为空",
      "answer": "答案",
      "sourceQuote": "对应原文短句",
      "tags": ["主题"]
    }
  ]
}

要求：$requirement
最多 ${min(input.maxCards, defaultMaxCards)} 张，答案必须能在原文中找到依据。
标题：${input.title}
正文：
$content''';
  }

  Future<FlashcardDeck> _parseAndSaveAiDeck(
    String rawText,
    FlashcardInput input,
  ) async {
    final parsed = _tryParseDeck(
      rawText: rawText,
      input: input,
      fallbackMode: FlashcardCreationMode.aiCards,
      persist: false,
    );
    if (parsed == null || parsed.cards.isEmpty) {
      throw StateError('AI 输出缺少可用卡片');
    }
    return _repository.saveDeck(parsed);
  }

  FlashcardDeck? _tryParseDeck({
    required String rawText,
    required FlashcardInput input,
    required FlashcardCreationMode fallbackMode,
    required bool persist,
  }) {
    final jsonText = _extractJson(rawText);
    if (jsonText == null) return null;
    try {
      final decoded = jsonDecode(jsonText);
      final map = decoded is List<dynamic>
          ? <String, dynamic>{'cards': decoded}
          : decoded as Map<String, dynamic>;
      final cardsJson = map['cards'] as List<dynamic>? ?? const [];
      if (cardsJson.isEmpty) return null;
      final now = DateTime.now();
      final deckId = flashcardId('deck_ai');
      final cards = <Flashcard>[];
      for (final item in cardsJson.take(input.maxCards)) {
        if (item is! Map) continue;
        final itemMap = item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final front = (itemMap['front'] ?? itemMap['question'] ?? '')
            .toString()
            .trim();
        final back =
            (itemMap['back'] ??
                    itemMap['explanation'] ??
                    itemMap['answer'] ??
                    '')
                .toString()
                .trim();
        final answer = (itemMap['answer'] ?? back).toString().trim();
        if (front.isEmpty || answer.isEmpty) continue;
        final cloze = (itemMap['clozeText'] ?? itemMap['cloze'] ?? '')
            .toString()
            .trim();
        final quote = (itemMap['sourceQuote'] ?? itemMap['sourceExcerpt'] ?? '')
            .toString()
            .trim();
        final type = cloze.isNotEmpty
            ? FlashcardType.cloze
            : FlashcardTypeX.fromStorage(
                (itemMap['type'] ?? itemMap['cardType'] ?? 'qa').toString(),
              );
        cards.add(
          Flashcard(
            id: flashcardId('card_ai'),
            deckId: deckId,
            orderIndex: cards.length,
            cardType: type,
            front: front,
            back: back.isEmpty ? answer : back,
            clozeText: cloze,
            answer: answer,
            sourceQuote: quote.isEmpty ? front : quote,
            sourceSentenceIndex: cards.length,
            tags: (itemMap['tags'] as List<dynamic>? ?? const [])
                .map((tag) => tag.toString())
                .where((tag) => tag.trim().isNotEmpty)
                .toList(),
            ttsText: [front, answer].where((part) => part.isNotEmpty).join('。'),
            metadata: {'ai': true},
          ),
        );
      }
      if (cards.isEmpty) return null;
      return FlashcardDeck(
        id: deckId,
        title: normalizeTitle((map['title'] ?? input.title).toString()),
        sourceDocumentId: input.documentId,
        mode: fallbackMode,
        requirement: input.requirement,
        status: FlashcardDeckStatus.ready,
        cards: cards,
        generationLog: const ['AI 分析内容', '提取知识点', '生成卡片', '校验答案'],
        createdAt: now,
        updatedAt: now,
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> splitSentences(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .trim();
    final matches = RegExp(r'[^。！？；.!?;\n]+[。！？；.!?;]?')
        .allMatches(cleaned)
        .map((match) => match.group(0)?.trim() ?? '')
        .where((sentence) => sentence.runes.length >= 8)
        .where(
          (sentence) => RegExp(r'[\u4e00-\u9fa5A-Za-z]').hasMatch(sentence),
        )
        .toList();
    return matches;
  }

  static List<String> splitLongSentence(String sentence) {
    if (sentence.runes.length <= 72) return [sentence];
    final parts = <String>[];
    final runes = sentence.runes.toList();
    for (var i = 0; i < runes.length; i += 56) {
      final part = String.fromCharCodes(runes.skip(i).take(64)).trim();
      if (part.runes.length >= 8) parts.add(part);
    }
    return parts;
  }

  Flashcard? _buildClozeCard({
    required String deckId,
    required String sentence,
    required int sentenceIndex,
    required int orderIndex,
  }) {
    final runes = sentence.runes.toList();
    final candidates = <int>[];
    for (var i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);
      if (RegExp(r'[\u4e00-\u9fa5A-Za-z]').hasMatch(char)) {
        candidates.add(i);
      }
    }
    if (candidates.length < 5) return null;

    final blankCount = switch (candidates.length) {
      < 16 => 1,
      < 32 => 2,
      < 56 => 3,
      _ => 4,
    };
    final gap = max(
      randomBlankMinGap,
      (candidates.length / (blankCount + 1)).floor(),
    );
    final blankIndexes = <int>[];
    for (var i = 1; i <= blankCount; i++) {
      final target = min(candidates.length - 1, i * gap);
      blankIndexes.add(candidates[target]);
      if (blankCount >= 3 &&
          target + 1 < candidates.length &&
          i == blankCount) {
        blankIndexes.add(candidates[target + 1]);
      }
    }
    final blankSet = blankIndexes.toSet();
    final answer = blankIndexes
        .map((index) => String.fromCharCode(runes[index]))
        .join('');
    final clozeText = List<String>.generate(runes.length, (index) {
      if (blankSet.contains(index)) return '＿';
      return String.fromCharCode(runes[index]);
    }).join();

    return Flashcard(
      id: flashcardId('card'),
      deckId: deckId,
      orderIndex: orderIndex,
      cardType: FlashcardType.cloze,
      front: clozeText,
      back: sentence,
      clozeText: clozeText,
      answer: answer,
      sourceQuote: sentence,
      sourceSentenceIndex: sentenceIndex,
      tags: const ['随机挖空'],
      ttsText: sentence,
      metadata: {
        'blankIndexes': blankIndexes,
        'blankCount': blankIndexes.length,
      },
    );
  }

  static String normalizeTitle(String title) {
    final normalized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '背诵闪卡';
    return normalized.length <= 32 ? normalized : normalized.substring(0, 32);
  }

  static String _visibleStep(DachengAiStreamEvent event) {
    final title = (event.raw['title'] ?? '').toString().trim();
    final message = (event.raw['message'] ?? event.text).toString().trim();
    return title.isNotEmpty ? title : message;
  }

  static String? _extractJson(String rawText) {
    final fence = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(rawText);
    final text = fence?.group(1) ?? rawText;
    final objectStart = text.indexOf('{');
    final arrayStart = text.indexOf('[');
    if (objectStart < 0 && arrayStart < 0) return null;
    if (arrayStart >= 0 && (objectStart < 0 || arrayStart < objectStart)) {
      final end = text.lastIndexOf(']');
      if (end <= arrayStart) return null;
      return text.substring(arrayStart, end + 1);
    }
    final end = text.lastIndexOf('}');
    if (end <= objectStart) return null;
    return text.substring(objectStart, end + 1);
  }
}
