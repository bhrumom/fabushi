import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'workspace_service.dart';

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
  final String? projectId; // Can be a project name or folder path

  const LocalAiConversationRecord({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
    this.projectId,
  });

  LocalAiConversationRecord copyWith({
    String? title,
    DateTime? updatedAt,
    List<LocalAiConversationMessage>? messages,
    String? projectId,
  }) {
    return LocalAiConversationRecord(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      projectId: projectId ?? this.projectId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
    'projectId': projectId,
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
      projectId: json['projectId']?.toString(),
    );
  }
}

class LocalAiConversationStore {
  LocalAiConversationStore._();

  static final LocalAiConversationStore instance = LocalAiConversationStore._();

  /// Loads all chat records from disk
  Future<List<LocalAiConversationRecord>> list() async {
    if (kIsWeb) return const []; // Fallback for web
    
    final chatsPath = await WorkspaceService.instance.getChatsPath();
    final dir = Directory(chatsPath);
    if (!await dir.exists()) return const [];

    final List<LocalAiConversationRecord> records = [];

    // Crawl through date folders (e.g., 2026-06-23)
    final dateDirs = dir.listSync().whereType<Directory>();
    for (final dateDir in dateDirs) {
      final files = dateDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content);
          records.add(LocalAiConversationRecord.fromJson(json));
        } catch (e) {
          debugPrint('Error reading chat file: ${file.path} - $e');
        }
      }
    }

    // Sort descending by updatedAt
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
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
    String? projectId,
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

    String recordTitle = title ?? existing?.title ?? _generateTitle(userText);

    final record = LocalAiConversationRecord(
      id: conversationId,
      title: recordTitle,
      updatedAt: now,
      messages: messages,
      projectId: projectId ?? existing?.projectId,
    );

    await _saveRecord(record);
  }

  Future<void> _saveRecord(LocalAiConversationRecord record) async {
    if (kIsWeb) return;
    
    // Save under the date folder of the record's initial creation time
    // For simplicity, we use the first message's creation date, or today
    final date = record.messages.isNotEmpty ? record.messages.first.createdAt : DateTime.now();
    final dateDir = await WorkspaceService.instance.getDailyChatsPath(date);
    
    final file = File(p.join(dateDir, 'chat_${record.id}.json'));
    await file.writeAsString(jsonEncode(record.toJson()), flush: true);
  }

  Future<void> delete(String id) async {
    if (kIsWeb) return;
    
    final chatsPath = await WorkspaceService.instance.getChatsPath();
    final dir = Directory(chatsPath);
    if (!await dir.exists()) return;

    final dateDirs = dir.listSync().whereType<Directory>();
    for (final dateDir in dateDirs) {
      final file = File(p.join(dateDir.path, 'chat_$id.json'));
      if (await file.exists()) {
        await file.delete();
        break; // Assuming IDs are unique globally
      }
    }
  }

  Future<void> updateTitle(String id, String newTitle) async {
    final record = await get(id);
    if (record != null) {
      final updated = record.copyWith(title: newTitle, updatedAt: DateTime.now());
      await _saveRecord(updated);
    }
  }

  String _generateTitle(String userText) {
    if (userText.isEmpty) return '新对话';
    final lines = userText.split('\n');
    var firstLine = lines.first.trim();
    if (firstLine.length > 20) {
      firstLine = '${firstLine.substring(0, 18)}...';
    }
    return firstLine.isEmpty ? '新对话' : firstLine;
  }
}
