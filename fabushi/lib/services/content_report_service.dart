import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

/// 举报原因类型
enum ReportReason {
  inappropriate('不当内容', 'inappropriate'),
  spam('垃圾信息/广告', 'spam'),
  harassment('骚扰/欺凌', 'harassment'),
  hateSpeech('仇恨言论', 'hate_speech'),
  violence('暴力内容', 'violence'),
  misinformation('虚假信息', 'misinformation'),
  copyright('侵犯版权', 'copyright'),
  other('其他', 'other');

  const ReportReason(this.label, this.value);
  final String label;
  final String value;
}

/// 内容举报服务
///
/// 管理用户对不当内容的举报功能
class ContentReportService {
  static final ContentReportService _instance = ContentReportService._();
  factory ContentReportService() => _instance;
  ContentReportService._();

  static const String _reportsKey = 'content_reports';

  /// 提交内容举报
  ///
  /// [contentId] 被举报内容的 ID
  /// [reason] 举报原因
  /// [description] 详细描述（可选）
  /// [reporterUserId] 举报者用户 ID
  Future<bool> reportContent({
    required String contentId,
    required ReportReason reason,
    String? description,
    String? reporterUserId,
  }) async {
    try {
      // 1. 尝试发送到后端
      final success = await _sendReportToBackend(
        contentId: contentId,
        reason: reason,
        description: description,
        reporterUserId: reporterUserId,
      );

      // 2. 本地记录举报（用于防止重复举报）
      await _saveLocalReport(contentId, reason.value);

      return success;
    } catch (e) {
      debugPrint('举报失败: $e');
      // 即使网络失败，也本地记录
      await _saveLocalReport(contentId, reason.value);
      return true; // 本地记录成功
    }
  }

  /// 检查是否已举报过某内容
  Future<bool> hasReported(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = prefs.getStringList(_reportsKey) ?? [];
    return reports.contains(contentId);
  }

  /// 发送举报到后端 API
  Future<bool> _sendReportToBackend({
    required String contentId,
    required ReportReason reason,
    String? description,
    String? reporterUserId,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/api/report');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'content_id': contentId,
          'reason': reason.value,
          'description': description ?? '',
          'reporter_user_id': reporterUserId ?? 'anonymous',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ 举报已提交到服务器: $contentId');
        return true;
      } else {
        debugPrint('⚠️ 举报提交失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ 举报网络请求失败: $e');
      return false;
    }
  }

  /// 本地记录举报
  Future<void> _saveLocalReport(String contentId, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = prefs.getStringList(_reportsKey) ?? [];
    if (!reports.contains(contentId)) {
      reports.add(contentId);
      await prefs.setStringList(_reportsKey, reports);
    }
  }
}
