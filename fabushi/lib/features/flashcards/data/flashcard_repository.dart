import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/flashcard_models.dart';

/// 首版本地优先持久化。
///
/// 当前仓库没有统一 SQLite 层，因此先用 SharedPreferences 保存文档、Deck 和学习进度。
/// 模型字段和 key 都按后续迁移预留，不影响旧版本启动。
class FlashcardRepository {
  static const String _documentsKey = 'flashcard_content_documents_v1';
  static const String _decksKey = 'flashcard_decks_v1';
  static const String _progressKey = 'flashcard_study_progress_v1';
  static const int _maxDecks = 80;
  static const int _maxDocuments = 80;

  Future<ContentDocument> saveDocument(ContentDocument document) async {
    final prefs = await SharedPreferences.getInstance();
    final documents = await listDocuments();
    final next = <ContentDocument>[
      document,
      ...documents.where((item) => item.id != document.id),
    ].take(_maxDocuments).toList();
    await prefs.setString(
      _documentsKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return document;
  }

  Future<List<ContentDocument>> listDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_documentsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ContentDocument.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ContentDocument?> getDocument(String id) async {
    final documents = await listDocuments();
    for (final document in documents) {
      if (document.id == id) return document;
    }
    return null;
  }

  Future<FlashcardDeck> saveDeck(FlashcardDeck deck) async {
    final prefs = await SharedPreferences.getInstance();
    final decks = await listDecks();
    final normalized = deck.copyWith(updatedAt: DateTime.now());
    final next = <FlashcardDeck>[
      normalized,
      ...decks.where((item) => item.id != normalized.id),
    ].take(_maxDecks).toList();
    await prefs.setString(
      _decksKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return normalized;
  }

  Future<List<FlashcardDeck>> listDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_decksKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final decks = list
          .whereType<Map<String, dynamic>>()
          .map(FlashcardDeck.fromJson)
          .toList();
      decks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return decks;
    } catch (_) {
      return const [];
    }
  }

  Future<FlashcardDeck?> getDeck(String id) async {
    final decks = await listDecks();
    for (final deck in decks) {
      if (deck.id == id) return deck;
    }
    return null;
  }

  Future<void> saveStudyProgress(FlashcardStudyProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadProgressMap();
    all[progress.deckId] = progress.copyWith(updatedAt: DateTime.now());
    await prefs.setString(
      _progressKey,
      jsonEncode(all.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  Future<FlashcardStudyProgress> getStudyProgress(String deckId) async {
    final all = await _loadProgressMap();
    return all[deckId] ?? FlashcardStudyProgress.empty(deckId);
  }

  Future<Map<String, FlashcardStudyProgress>> _loadProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null || raw.trim().isEmpty)
      return <String, FlashcardStudyProgress>{};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(key, FlashcardStudyProgress.fromJson(value));
        }
        return MapEntry(key, FlashcardStudyProgress.empty(key));
      });
    } catch (_) {
      return <String, FlashcardStudyProgress>{};
    }
  }
}
