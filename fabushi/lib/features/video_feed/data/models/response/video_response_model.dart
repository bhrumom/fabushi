// Firebase/Firestore removed for Windows compatibility
import 'package:global_dharma_sharing/features/video_feed/domain/entities/video_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'video_response_model.g.dart';

@JsonSerializable()
class VideoResponseModel {
  const VideoResponseModel({
    required this.id,
    required this.username,
    required this.description,
    required this.videoUrl,
    required this.profileImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.timestamp,
    this.contentType,
    this.textContent,
  });

  final String id;
  final String username;
  final String description;
  final String videoUrl;
  final String profileImageUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime timestamp;
  final String? contentType;
  final String? textContent;

  /// Factory constructor from JSON
  factory VideoResponseModel.fromJson(Map<String, dynamic> json) =>
      _$VideoResponseModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$VideoResponseModelToJson(this);

  /// Factory constructor to create a VideoResponseModel from a Map (e.g., from API response)
  factory VideoResponseModel.fromMap(Map<String, dynamic> data, String docId) {
    return VideoResponseModel(
      id: docId,
      username: data['username'] is String ? data['username'] as String : '',
      description: data['description'] is String ? data['description'] as String : '',
      videoUrl: data['videoUrl'] is String ? data['videoUrl'] as String : '',
      profileImageUrl: data['profileImageUrl'] is String ? data['profileImageUrl'] as String : '',
      likeCount: _safeInt(data['likeCount']),
      commentCount: _safeInt(data['commentCount']),
      shareCount: _safeInt(data['shareCount']),
      timestamp: _parseTimestamp(data['timestamp']),
      contentType: data['contentType'] is String ? data['contentType'] as String : null,
      textContent: data['textContent'] is String ? data['textContent'] as String : null,
    );
  }

  /// Convert to domain entity
  VideoEntity toEntity() {
    return VideoEntity(
      id: id,
      username: username,
      description: description,
      videoUrl: videoUrl,
      profileImageUrl: profileImageUrl,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      timestamp: timestamp,
      contentType: contentType == 'text' ? ContentType.text : ContentType.video,
      textContent: textContent,
    );
  }

  /// Helper for JSON serialization of DateTime
  static DateTime _timestampFromJson(dynamic json) {
    if (json is DateTime) return json;
    if (json is String) return DateTime.tryParse(json) ?? DateTime.now();
    if (json is Map) {
      // Handle Firestore-like timestamp format
      final seconds = json['_seconds'] as int? ?? json['seconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    return DateTime.now();
  }

  /// Helper for JSON deserialization of DateTime
  static String _timestampToJson(DateTime timestamp) {
    return timestamp.toIso8601String();
  }

  /// Parse timestamp from various formats
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is Map) {
      final seconds = value['_seconds'] as int? ?? value['seconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    return DateTime.now();
  }
}

/// Helper function to safely convert a dynamic value to an int
int _safeInt(dynamic value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}
