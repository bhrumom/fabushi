import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalAiConversationMessage {
  final String role;
  final String content;
  final DateTime createdAt;

  const LocalAiConversationMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LocalAiConversationMessage.fromJson(Map<String, dynamic> json) {
    return LocalAiConversationMessage(
      role: (json['role'] ?? 'assistant').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class LocalAiConversationRecord {
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<LocalAiConversationMessage> messages;

  const LocalAiConversationRecord({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  LocalAiConversationRecord copyWith({
    String? title,
    DateTime? updatedAt,
    List<LocalAiConversationMessage>? messages,
  }) {
    return LocalAiConversationRecord(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory LocalAiConversationRecord.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return LocalAiConversationRecord(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '新对话').toString(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map(
                  (item) => LocalAiConversationMessage.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class LocalAiConversationStore {
  LocalAiConversationStore._();

  static final LocalAiConversationStore instance = LocalAiConversationStore._();
  static const String _storageKey = 'openclaw_local_conversations_v1';
  static const int _maxConversations = 80;
  static const int _maxMessagesPerConversation = 80;

  Future<List<LocalAiConversationRecord>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = decoded
          .whereType<Map>()
          .map(
            (item) => LocalAiConversationRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<LocalAiConversationRecord?> get(String id) async {
    final items = await list();
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> upsertTurn({
    required String conversationId,
    required String userText,
    required String assistantText,
    String? title,
  }) async {
    final now = DateTime.now();
    final items = await list();
    final index = items.indexWhere((item) => item.id == conversationId);
    final existing = index >= 0 ? items[index] : null;
    final messages = <LocalAiConversationMessage>[
      ...?existing?.messages,
      LocalAiConversationMessage(
        role: 'user',
        content: userText,
        createdAt: now,
      ),
      LocalAiConversationMessage(
        role: 'assistant',
        content: assistantText,
        createdAt: now,
      ),
    ];

    final trimmedMessages = messages.length > _maxMessagesPerConversation
        ? messages.sublist(messages.length - _maxMessagesPerConversation)
        : messages;

    final next = LocalAiConversationRecord(
      id: conversationId,
      title: title ?? existing?.title ?? _titleFrom(userText),
      updatedAt: now,
      messages: trimmedMessages,
    );

    if (index >= 0) {
      items[index] = next;
    } else {
      items.insert(0, next);
    }

    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final trimmed = items.length > _maxConversations
        ? items.sublist(0, _maxConversations)
        : items;
    await _save(trimmed);
  }

  Future<void> delete(String id) async {
    final items = await list();
    items.removeWhere((item) => item.id == id);
    await _save(items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _save(List<LocalAiConversationRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  String _titleFrom(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '新对话';
    return normalized.length <= 22
        ? normalized
        : '${normalized.substring(0, 22)}…';
  }
}
