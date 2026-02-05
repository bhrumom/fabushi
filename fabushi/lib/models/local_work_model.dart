import 'package:uuid/uuid.dart';

class LocalWorkModel {
  final String id;
  final String contentId;
  final String title;
  final String filePath;
  final int durationMs; // Duration in milliseconds
  final DateTime createdAt;
  final String? coverUrl;

  LocalWorkModel({
    required this.id,
    required this.contentId,
    required this.title,
    required this.filePath,
    required this.durationMs,
    required this.createdAt,
    this.coverUrl,
  });

  factory LocalWorkModel.create({
    required String contentId,
    required String title,
    required String filePath,
    required int durationMs,
    String? coverUrl,
  }) {
    return LocalWorkModel(
      id: const Uuid().v4(),
      contentId: contentId,
      title: title,
      filePath: filePath,
      durationMs: durationMs,
      createdAt: DateTime.now(),
      coverUrl: coverUrl,
    );
  }

  factory LocalWorkModel.fromMap(Map<String, dynamic> map) {
    return LocalWorkModel(
      id: map['id'] as String,
      contentId: map['content_id'] as String,
      title: map['title'] as String,
      filePath: map['file_path'] as String,
      durationMs: map['duration_ms'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      coverUrl: map['cover_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content_id': contentId,
      'title': title,
      'file_path': filePath,
      'duration_ms': durationMs,
      'created_at': createdAt.millisecondsSinceEpoch,
      'cover_url': coverUrl,
    };
  }
}
