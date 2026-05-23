import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

class CbetaSendText {
  final String work;
  final int juan;
  final String title;
  final String byline;
  final String category;
  final String fileName;
  final String content;
  final String sourceUrl;

  const CbetaSendText({
    required this.work,
    required this.juan,
    required this.title,
    required this.byline,
    required this.category,
    required this.fileName,
    required this.content,
    required this.sourceUrl,
  });

  factory CbetaSendText.fromJson(Map<String, dynamic> json) {
    return CbetaSendText(
      work: (json['work'] ?? '').toString(),
      juan: _parseInt(json['juan']),
      title: (json['title'] ?? '').toString(),
      byline: (json['byline'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? 1;
  }
}

class CbetaSendTextResult {
  final List<CbetaSendText> items;
  final List<dynamic> errors;
  final String api;

  const CbetaSendTextResult({
    required this.items,
    required this.errors,
    required this.api,
  });
}

class CbetaSendTextException implements Exception {
  final String message;
  final List<Map<String, dynamic>> attempts;

  const CbetaSendTextException(this.message, this.attempts);

  @override
  String toString() {
    final details = attempts.isEmpty ? '' : ' ${jsonEncode(attempts)}';
    return '$message$details';
  }
}

class CbetaSendTextService {
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 15);

  Future<CbetaSendTextResult> fetchDefaultSendTexts({int limit = 12}) async {
    final uri = AppConfig.buildBackendUri(
      AppConfig.cbetaSendTextsEndpoint,
      queryParameters: {'limit': limit.toString()},
    );
    final attempts = <Map<String, dynamic>>[];

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      final startedAt = DateTime.now();
      try {
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(_timeout);
        final body = utf8.decode(response.bodyBytes);
        final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
        final attemptInfo = <String, dynamic>{
          'attempt': attempt,
          'url': uri.toString(),
          'statusCode': response.statusCode,
          'durationMs': durationMs,
          'body': _summarizeBody(body),
        };

        if (response.statusCode < 200 || response.statusCode >= 300) {
          attempts.add(attemptInfo);
          await _delayBeforeRetry(attempt);
          continue;
        }

        final decoded = json.decode(body);
        if (decoded is! Map<String, dynamic>) {
          attempts.add({...attemptInfo, 'error': '响应不是 JSON 对象'});
          await _delayBeforeRetry(attempt);
          continue;
        }

        final rawItems = decoded['items'];
        final items = rawItems is List
            ? rawItems
                  .whereType<Map<String, dynamic>>()
                  .map(CbetaSendText.fromJson)
                  .where((item) => item.content.trim().isNotEmpty)
                  .toList()
            : <CbetaSendText>[];
        final serverErrors = decoded['errors'] is List
            ? decoded['errors'] as List<dynamic>
            : <dynamic>[];

        if (items.isEmpty) {
          attempts.add({
            ...attemptInfo,
            'error': '后端没有返回可发送的经文',
            'serverErrors': serverErrors,
          });
          await _delayBeforeRetry(attempt);
          continue;
        }

        return CbetaSendTextResult(
          items: items,
          errors: serverErrors,
          api: (decoded['api'] ?? '').toString(),
        );
      } on TimeoutException catch (error) {
        attempts.add({
          'attempt': attempt,
          'url': uri.toString(),
          'error': '请求超时: ${error.message ?? _timeout.toString()}',
        });
        await _delayBeforeRetry(attempt);
      } catch (error) {
        attempts.add({
          'attempt': attempt,
          'url': uri.toString(),
          'error': error.toString(),
        });
        await _delayBeforeRetry(attempt);
      }
    }

    throw CbetaSendTextException('CBETA 经文下载失败，已重试 $_maxRetries 次。', attempts);
  }

  static Future<void> _delayBeforeRetry(int attempt) async {
    if (attempt >= _maxRetries) return;
    await Future.delayed(Duration(milliseconds: 300 * attempt));
  }

  static String _summarizeBody(String body) {
    if (body.length <= 800) return body;
    return '${body.substring(0, 800)}...';
  }
}
