import 'dart:convert';

/// 背诵闪卡首版本地模型。
///
/// 字段按上传的数据库设计文档预留 documentId、status、metadata 等扩展点，
/// 便于后续迁移到 SQLite/云同步时保持向后兼容。
enum FlashcardCreationMode { randomCloze, aiCards }

enum FlashcardDeckStatus { draft, generating, ready, failed, archived }

enum FlashcardType { cloze, basic, qa }

extension FlashcardCreationModeX on FlashcardCreationMode {
  String get storageValue => switch (this) {
    FlashcardCreationMode.randomCloze => 'random_cloze',
    FlashcardCreationMode.aiCards => 'ai_cards',
  };

  String get label => switch (this) {
    FlashcardCreationMode.randomCloze => '随机挖空',
    FlashcardCreationMode.aiCards => 'AI 制卡',
  };

  static FlashcardCreationMode fromStorage(String value) {
    return switch (value) {
      'ai_cards' => FlashcardCreationMode.aiCards,
      _ => FlashcardCreationMode.randomCloze,
    };
  }
}

extension FlashcardDeckStatusX on FlashcardDeckStatus {
  String get storageValue => switch (this) {
    FlashcardDeckStatus.draft => 'draft',
    FlashcardDeckStatus.generating => 'generating',
    FlashcardDeckStatus.ready => 'ready',
    FlashcardDeckStatus.failed => 'failed',
    FlashcardDeckStatus.archived => 'archived',
  };

  static FlashcardDeckStatus fromStorage(String value) {
    return switch (value) {
      'draft' => FlashcardDeckStatus.draft,
      'generating' => FlashcardDeckStatus.generating,
      'failed' => FlashcardDeckStatus.failed,
      'archived' => FlashcardDeckStatus.archived,
      _ => FlashcardDeckStatus.ready,
    };
  }
}

extension FlashcardTypeX on FlashcardType {
  String get storageValue => switch (this) {
    FlashcardType.basic => 'basic',
    FlashcardType.qa => 'qa',
    FlashcardType.cloze => 'cloze',
  };

  String get label => switch (this) {
    FlashcardType.basic => '记忆',
    FlashcardType.qa => '问答',
    FlashcardType.cloze => '挖空',
  };

  static FlashcardType fromStorage(String value) {
    return switch (value) {
      'basic' => FlashcardType.basic,
      'qa' => FlashcardType.qa,
      _ => FlashcardType.cloze,
    };
  }
}

class ContentSource {
  final String id;
  final String sourceType;
  final String rawText;
  final String? url;
  final String title;
  final String sourceApp;
  final String mimeType;
  final DateTime receivedAt;
  final String rawTextHash;

  const ContentSource({
    required this.id,
    required this.sourceType,
    required this.rawText,
    this.url,
    required this.title,
    required this.sourceApp,
    required this.mimeType,
    required this.receivedAt,
    required this.rawTextHash,
  });

  ContentSource copyWith({
    String? id,
    String? sourceType,
    String? rawText,
    String? url,
    String? title,
    String? sourceApp,
    String? mimeType,
    DateTime? receivedAt,
    String? rawTextHash,
  }) {
    return ContentSource(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      rawText: rawText ?? this.rawText,
      url: url ?? this.url,
      title: title ?? this.title,
      sourceApp: sourceApp ?? this.sourceApp,
      mimeType: mimeType ?? this.mimeType,
      receivedAt: receivedAt ?? this.receivedAt,
      rawTextHash: rawTextHash ?? this.rawTextHash,
    );
  }

  factory ContentSource.fromJson(Map<String, dynamic> json) {
    return ContentSource(
      id: (json['id'] ?? '').toString(),
      sourceType: (json['sourceType'] ?? 'composer_text').toString(),
      rawText: (json['rawText'] ?? '').toString(),
      url: _emptyToNull(json['url']?.toString()),
      title: (json['title'] ?? '未命名内容').toString(),
      sourceApp: (json['sourceApp'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      receivedAt:
          DateTime.tryParse((json['receivedAt'] ?? '').toString()) ??
          DateTime.now(),
      rawTextHash: (json['rawTextHash'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType,
    'rawText': rawText,
    'url': url,
    'title': title,
    'sourceApp': sourceApp,
    'mimeType': mimeType,
    'receivedAt': receivedAt.toIso8601String(),
    'rawTextHash': rawTextHash,
  };
}

class ContentDocument {
  final String id;
  final String sourceId;
  final String title;
  final String summary;
  final String fullText;
  final int charCount;
  final int tokenCount;
  final String language;
  final DateTime extractedAt;
  final String? sourceUrl;

  const ContentDocument({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.summary,
    required this.fullText,
    required this.charCount,
    required this.tokenCount,
    required this.language,
    required this.extractedAt,
    this.sourceUrl,
  });

  factory ContentDocument.fromJson(Map<String, dynamic> json) {
    return ContentDocument(
      id: (json['id'] ?? '').toString(),
      sourceId: (json['sourceId'] ?? '').toString(),
      title: (json['title'] ?? '未命名文档').toString(),
      summary: (json['summary'] ?? '').toString(),
      fullText: (json['fullText'] ?? '').toString(),
      charCount: _readInt(json['charCount']),
      tokenCount: _readInt(json['tokenCount']),
      language: (json['language'] ?? 'zh').toString(),
      extractedAt:
          DateTime.tryParse((json['extractedAt'] ?? '').toString()) ??
          DateTime.now(),
      sourceUrl: _emptyToNull(json['sourceUrl']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'title': title,
    'summary': summary,
    'fullText': fullText,
    'charCount': charCount,
    'tokenCount': tokenCount,
    'language': language,
    'extractedAt': extractedAt.toIso8601String(),
    'sourceUrl': sourceUrl,
  };
}

class PreparedContent {
  final ContentSource source;
  final ContentDocument? document;
  final String title;
  final String text;
  final String summary;
  final String previewText;
  final bool isLong;
  final bool isFailed;
  final String? errorMessage;

  const PreparedContent({
    required this.source,
    this.document,
    required this.title,
    required this.text,
    required this.summary,
    required this.previewText,
    required this.isLong,
    this.isFailed = false,
    this.errorMessage,
  });

  String? get sourceUrl => source.url;
  String get displaySource => source.sourceApp.isNotEmpty
      ? source.sourceApp
      : (source.url != null ? '链接' : '文本');
  int get charCount => text.charactersCount;
  bool get hasDocument => document != null;

  PreparedContent copyWith({
    ContentSource? source,
    ContentDocument? document,
    String? title,
    String? text,
    String? summary,
    String? previewText,
    bool? isLong,
    bool? isFailed,
    String? errorMessage,
  }) {
    return PreparedContent(
      source: source ?? this.source,
      document: document ?? this.document,
      title: title ?? this.title,
      text: text ?? this.text,
      summary: summary ?? this.summary,
      previewText: previewText ?? this.previewText,
      isLong: isLong ?? this.isLong,
      isFailed: isFailed ?? this.isFailed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class Flashcard {
  final String id;
  final String deckId;
  final int orderIndex;
  final FlashcardType cardType;
  final String front;
  final String back;
  final String clozeText;
  final String answer;
  final String sourceQuote;
  final int sourceSentenceIndex;
  final List<String> tags;
  final String ttsText;
  final Map<String, dynamic> metadata;

  const Flashcard({
    required this.id,
    required this.deckId,
    required this.orderIndex,
    required this.cardType,
    required this.front,
    required this.back,
    required this.clozeText,
    required this.answer,
    required this.sourceQuote,
    required this.sourceSentenceIndex,
    this.tags = const [],
    required this.ttsText,
    this.metadata = const {},
  });

  Flashcard copyWith({
    String? id,
    String? deckId,
    int? orderIndex,
    FlashcardType? cardType,
    String? front,
    String? back,
    String? clozeText,
    String? answer,
    String? sourceQuote,
    int? sourceSentenceIndex,
    List<String>? tags,
    String? ttsText,
    Map<String, dynamic>? metadata,
  }) {
    return Flashcard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      orderIndex: orderIndex ?? this.orderIndex,
      cardType: cardType ?? this.cardType,
      front: front ?? this.front,
      back: back ?? this.back,
      clozeText: clozeText ?? this.clozeText,
      answer: answer ?? this.answer,
      sourceQuote: sourceQuote ?? this.sourceQuote,
      sourceSentenceIndex: sourceSentenceIndex ?? this.sourceSentenceIndex,
      tags: tags ?? this.tags,
      ttsText: ttsText ?? this.ttsText,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: (json['id'] ?? '').toString(),
      deckId: (json['deckId'] ?? '').toString(),
      orderIndex: _readInt(json['orderIndex']),
      cardType: FlashcardTypeX.fromStorage((json['cardType'] ?? '').toString()),
      front: (json['front'] ?? '').toString(),
      back: (json['back'] ?? '').toString(),
      clozeText: (json['clozeText'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      sourceQuote: (json['sourceQuote'] ?? '').toString(),
      sourceSentenceIndex: _readInt(json['sourceSentenceIndex']),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      ttsText: (json['ttsText'] ?? '').toString(),
      metadata: _readMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deckId': deckId,
    'orderIndex': orderIndex,
    'cardType': cardType.storageValue,
    'front': front,
    'back': back,
    'clozeText': clozeText,
    'answer': answer,
    'sourceQuote': sourceQuote,
    'sourceSentenceIndex': sourceSentenceIndex,
    'tags': tags,
    'ttsText': ttsText,
    'metadata': metadata,
  };
}

class FlashcardDeck {
  final String id;
  final String title;
  final String? sourceDocumentId;
  final FlashcardCreationMode mode;
  final String requirement;
  final FlashcardDeckStatus status;
  final List<Flashcard> cards;
  final List<String> generationLog;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastStudiedAt;
  final int lastStudiedIndex;

  const FlashcardDeck({
    required this.id,
    required this.title,
    this.sourceDocumentId,
    required this.mode,
    this.requirement = '',
    this.status = FlashcardDeckStatus.ready,
    this.cards = const [],
    this.generationLog = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastStudiedAt,
    this.lastStudiedIndex = 0,
  });

  int get cardCount => cards.length;
  bool get isReady => status == FlashcardDeckStatus.ready && cards.isNotEmpty;

  FlashcardDeck copyWith({
    String? id,
    String? title,
    String? sourceDocumentId,
    FlashcardCreationMode? mode,
    String? requirement,
    FlashcardDeckStatus? status,
    List<Flashcard>? cards,
    List<String>? generationLog,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastStudiedAt,
    int? lastStudiedIndex,
  }) {
    return FlashcardDeck(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      mode: mode ?? this.mode,
      requirement: requirement ?? this.requirement,
      status: status ?? this.status,
      cards: cards ?? this.cards,
      generationLog: generationLog ?? this.generationLog,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      lastStudiedIndex: lastStudiedIndex ?? this.lastStudiedIndex,
    );
  }

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    return FlashcardDeck(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '背诵闪卡').toString(),
      sourceDocumentId: _emptyToNull(json['sourceDocumentId']?.toString()),
      mode: FlashcardCreationModeX.fromStorage((json['mode'] ?? '').toString()),
      requirement: (json['requirement'] ?? '').toString(),
      status: FlashcardDeckStatusX.fromStorage(
        (json['status'] ?? '').toString(),
      ),
      cards: (json['cards'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Flashcard.fromJson)
          .toList(),
      generationLog: (json['generationLog'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      lastStudiedAt: DateTime.tryParse(
        (json['lastStudiedAt'] ?? '').toString(),
      ),
      lastStudiedIndex: _readInt(json['lastStudiedIndex']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceDocumentId': sourceDocumentId,
    'mode': mode.storageValue,
    'requirement': requirement,
    'status': status.storageValue,
    'cardCount': cardCount,
    'cards': cards.map((card) => card.toJson()).toList(),
    'generationLog': generationLog,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastStudiedAt': lastStudiedAt?.toIso8601String(),
    'lastStudiedIndex': lastStudiedIndex,
  };
}

class FlashcardStudyProgress {
  final String deckId;
  final int currentIndex;
  final Set<String> masteredCardIds;
  final Set<String> favoriteCardIds;
  final DateTime updatedAt;

  const FlashcardStudyProgress({
    required this.deckId,
    required this.currentIndex,
    this.masteredCardIds = const {},
    this.favoriteCardIds = const {},
    required this.updatedAt,
  });

  factory FlashcardStudyProgress.empty(String deckId) {
    return FlashcardStudyProgress(
      deckId: deckId,
      currentIndex: 0,
      updatedAt: DateTime.now(),
    );
  }

  FlashcardStudyProgress copyWith({
    int? currentIndex,
    Set<String>? masteredCardIds,
    Set<String>? favoriteCardIds,
    DateTime? updatedAt,
  }) {
    return FlashcardStudyProgress(
      deckId: deckId,
      currentIndex: currentIndex ?? this.currentIndex,
      masteredCardIds: masteredCardIds ?? this.masteredCardIds,
      favoriteCardIds: favoriteCardIds ?? this.favoriteCardIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FlashcardStudyProgress.fromJson(Map<String, dynamic> json) {
    return FlashcardStudyProgress(
      deckId: (json['deckId'] ?? '').toString(),
      currentIndex: _readInt(json['currentIndex']),
      masteredCardIds: (json['masteredCardIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toSet(),
      favoriteCardIds: (json['favoriteCardIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toSet(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'deckId': deckId,
    'currentIndex': currentIndex,
    'masteredCardIds': masteredCardIds.toList(),
    'favoriteCardIds': favoriteCardIds.toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

String flashcardId(String prefix) {
  final micros = DateTime.now().microsecondsSinceEpoch;
  return '${prefix}_${micros}_${micros.remainder(9973)}';
}

String encodeFlashcardJson(Object? object) => jsonEncode(object);

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

extension _FlashcardStringLength on String {
  int get charactersCount => runes.length;
}
