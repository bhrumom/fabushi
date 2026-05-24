import 'dart:convert';

import 'package:crypto/crypto.dart';

enum PracticeBookSourceType { file, url, manual, cloud }

enum PracticeBookSyncStatus { localOnly, pendingUpload, synced, syncFailed }

PracticeBookSourceType practiceBookSourceTypeFromString(String? value) {
  return PracticeBookSourceType.values.firstWhere(
    (item) => item.name == value,
    orElse: () => PracticeBookSourceType.manual,
  );
}

PracticeBookSyncStatus practiceBookSyncStatusFromString(String? value) {
  return PracticeBookSyncStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => PracticeBookSyncStatus.localOnly,
  );
}

class PracticeBook {
  final String id;
  final String practiceTitle;
  final String title;
  final PracticeBookSourceType sourceType;
  final String? sourceUrl;
  final String? sourceFileName;
  final String contentHash;
  final String plainText;
  final String normalizedText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PracticeBookSyncStatus syncStatus;
  final String? remoteObjectKey;
  final bool isActive;

  const PracticeBook({
    required this.id,
    required this.practiceTitle,
    required this.title,
    required this.sourceType,
    this.sourceUrl,
    this.sourceFileName,
    required this.contentHash,
    required this.plainText,
    required this.normalizedText,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = PracticeBookSyncStatus.localOnly,
    this.remoteObjectKey,
    this.isActive = true,
  });

  factory PracticeBook.create({
    required String id,
    required String practiceTitle,
    required String title,
    required PracticeBookSourceType sourceType,
    String? sourceUrl,
    String? sourceFileName,
    required String plainText,
    String? remoteObjectKey,
    PracticeBookSyncStatus syncStatus = PracticeBookSyncStatus.pendingUpload,
  }) {
    final normalizedText = PracticeBookText.normalizeForMatching(plainText);
    final now = DateTime.now();
    return PracticeBook(
      id: id,
      practiceTitle: practiceTitle,
      title: title,
      sourceType: sourceType,
      sourceUrl: sourceUrl,
      sourceFileName: sourceFileName,
      contentHash: PracticeBookText.sha256Of(plainText),
      plainText: plainText,
      normalizedText: normalizedText,
      createdAt: now,
      updatedAt: now,
      syncStatus: syncStatus,
      remoteObjectKey: remoteObjectKey,
      isActive: true,
    );
  }

  factory PracticeBook.fromMap(Map<String, dynamic> map) {
    return PracticeBook(
      id: map['id'].toString(),
      practiceTitle: (map['practice_title'] ?? map['practiceTitle'] ?? '')
          .toString(),
      title: (map['title'] ?? '').toString(),
      sourceType: practiceBookSourceTypeFromString(
        (map['source_type'] ?? map['sourceType'])?.toString(),
      ),
      sourceUrl: _emptyToNull(map['source_url'] ?? map['sourceUrl']),
      sourceFileName: _emptyToNull(
        map['source_file_name'] ?? map['sourceFileName'],
      ),
      contentHash: (map['content_hash'] ?? map['contentHash'] ?? '').toString(),
      plainText: (map['plain_text'] ?? map['plainText'] ?? '').toString(),
      normalizedText:
          (map['normalized_text'] ??
                  map['normalizedText'] ??
                  PracticeBookText.normalizeForMatching(
                    (map['plain_text'] ?? map['plainText'] ?? '').toString(),
                  ))
              .toString(),
      createdAt:
          DateTime.tryParse(
            (map['created_at'] ?? map['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(
            (map['updated_at'] ?? map['updatedAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      syncStatus: practiceBookSyncStatusFromString(
        (map['sync_status'] ?? map['syncStatus'])?.toString(),
      ),
      remoteObjectKey: _emptyToNull(
        map['remote_object_key'] ?? map['remoteObjectKey'],
      ),
      isActive:
          map['is_active'] == true ||
          map['is_active'] == 1 ||
          map['isActive'] == true ||
          map['isActive'] == 1,
    );
  }

  factory PracticeBook.fromJson(Map<String, dynamic> json) {
    return PracticeBook.fromMap(json);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'practice_title': practiceTitle,
      'title': title,
      'source_type': sourceType.name,
      'source_url': sourceUrl,
      'source_file_name': sourceFileName,
      'content_hash': contentHash,
      'plain_text': plainText,
      'normalized_text': normalizedText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
      'remote_object_key': remoteObjectKey,
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'practiceTitle': practiceTitle,
    'title': title,
    'sourceType': sourceType.name,
    'sourceUrl': sourceUrl,
    'sourceFileName': sourceFileName,
    'contentHash': contentHash,
    'plainText': plainText,
    'normalizedText': normalizedText,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'syncStatus': syncStatus.name,
    'remoteObjectKey': remoteObjectKey,
    'isActive': isActive,
  };

  PracticeBook copyWith({
    String? id,
    String? practiceTitle,
    String? title,
    PracticeBookSourceType? sourceType,
    String? sourceUrl,
    String? sourceFileName,
    String? contentHash,
    String? plainText,
    String? normalizedText,
    DateTime? createdAt,
    DateTime? updatedAt,
    PracticeBookSyncStatus? syncStatus,
    String? remoteObjectKey,
    bool? isActive,
  }) {
    return PracticeBook(
      id: id ?? this.id,
      practiceTitle: practiceTitle ?? this.practiceTitle,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      contentHash: contentHash ?? this.contentHash,
      plainText: plainText ?? this.plainText,
      normalizedText: normalizedText ?? this.normalizedText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteObjectKey: remoteObjectKey ?? this.remoteObjectKey,
      isActive: isActive ?? this.isActive,
    );
  }

  static String? _emptyToNull(dynamic value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }
}

class PracticeBookText {
  static String normalizeForMatching(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[\u0000-\u001f]'), ' ')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
  }

  static String normalizePlainText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String sha256Of(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  static String titleFromText(String text, {String fallback = '功课本'}) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return fallback;
    final first = lines.first.replaceAll(RegExp(r'^[#>\s]+'), '').trim();
    if (first.isEmpty) return fallback;
    return first.length > 32 ? first.substring(0, 32) : first;
  }
}
