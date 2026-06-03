import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
}

class CbetaSendTextResult {
  final List<CbetaSendText> items;
  final List<dynamic> errors;
  final String api;
  final bool hasMore;
  final String? nextCursor;

  const CbetaSendTextResult({
    required this.items,
    required this.errors,
    required this.api,
    this.hasMore = false,
    this.nextCursor,
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

class _CbetaJsonResult {
  final Map<String, dynamic> data;
  final String apiRoot;
  final Uri url;
  final List<Map<String, dynamic>> attempts;

  const _CbetaJsonResult({
    required this.data,
    required this.apiRoot,
    required this.url,
    required this.attempts,
  });
}

class CbetaSendTextService {
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 15);
  static const String _selfHostedApiRoot = 'https://144.24.17.21.sslip.io';
  static const List<String> _apiRoots = [_selfHostedApiRoot];

  static const List<String> _defaultSendWorks = [
    'T0365',
    'T0251',
    'T0235',
    'T0262',
    'T0279',
    'T0366',
    'T0001',
    'T0099',
    'T0220',
    'T0374',
    'T0261',
    'T0278',
  ];

  Future<CbetaSendTextResult> fetchDefaultSendTexts({int limit = 12}) {
    return fetchSendTextsPage(limit: limit);
  }

  Future<CbetaSendTextResult> fetchSendTextsPage({
    int limit = 1,
    int offset = 0,
    String? cursor,
  }) async {
    final pageLimit = limit.clamp(1, 24).toInt();
    final startIndex =
        _parseCursor(cursor) ??
        offset.clamp(0, _defaultSendWorks.length).toInt();
    final items = <CbetaSendText>[];
    final errors = <Map<String, dynamic>>[];
    var index = startIndex;

    while (index < _defaultSendWorks.length && items.length < pageLimit) {
      final work = _defaultSendWorks[index];
      index++;

      try {
        final result = await _fetchJsonWithRetry('juans', {
          'work': work,
          'juan': '1',
          'work_info': '1',
          'toc': '1',
        });
        items.add(_toCbetaItem(work, 1, result));
      } catch (error) {
        errors.add(_normalizeError(work, 1, error));
      }
    }

    if (items.isEmpty) {
      throw CbetaSendTextException(
        'CBETA direct API returned no sendable scripture.',
        errors,
      );
    }

    final hasMore = index < _defaultSendWorks.length;
    return CbetaSendTextResult(
      items: items,
      errors: errors,
      api: _selfHostedApiRoot,
      hasMore: hasMore,
      nextCursor: hasMore ? index.toString() : null,
    );
  }

  Future<_CbetaJsonResult> _fetchJsonWithRetry(
    String path,
    Map<String, String> params,
  ) async {
    final attempts = <Map<String, dynamic>>[];

    for (final apiRoot in _apiRoots) {
      final uri = _buildCbetaUri(apiRoot, path, params);

      for (var attempt = 1; attempt <= _maxRetries; attempt++) {
        final startedAt = DateTime.now();
        try {
          final response = await http
              .get(uri, headers: {'Accept': 'application/json'})
              .timeout(_timeout);
          final body = utf8.decode(response.bodyBytes, allowMalformed: true);
          final detail = <String, dynamic>{
            'attempt': attempt,
            'apiRoot': apiRoot,
            'url': uri.toString(),
            'statusCode': response.statusCode,
            'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          };

          if (response.statusCode < 200 || response.statusCode >= 300) {
            attempts.add({...detail, 'body': _summarizeBody(body)});
            await _delayBeforeRetry(attempt);
            continue;
          }

          final decoded = json.decode(body);
          if (decoded is! Map<String, dynamic>) {
            attempts.add({...detail, 'error': 'Response is not a JSON object'});
            await _delayBeforeRetry(attempt);
            continue;
          }

          if (!_hasUsableCbetaPayload(path, decoded)) {
            attempts.add({
              ...detail,
              'error': _describeUnusablePayload(path, decoded),
              'body': _summarizeBody(body),
            });
            await _delayBeforeRetry(attempt);
            continue;
          }

          return _CbetaJsonResult(
            data: decoded,
            apiRoot: apiRoot,
            url: uri,
            attempts: [...attempts, detail],
          );
        } on TimeoutException catch (error) {
          attempts.add({
            'attempt': attempt,
            'apiRoot': apiRoot,
            'url': uri.toString(),
            'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
            'error': 'Request timed out: ${error.message ?? _timeout}',
          });
          await _delayBeforeRetry(attempt);
        } catch (error) {
          attempts.add({
            'attempt': attempt,
            'apiRoot': apiRoot,
            'url': uri.toString(),
            'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
            'error': error.toString(),
          });
          await _delayBeforeRetry(attempt);
        }
      }
    }

    throw CbetaSendTextException('CBETA direct API request failed.', attempts);
  }

  CbetaSendText _toCbetaItem(
    String requestedWork,
    int requestedJuan,
    _CbetaJsonResult result,
  ) {
    final data = result.data;
    final workInfo = data['work_info'] is Map
        ? Map<String, dynamic>.from(data['work_info'] as Map)
        : <String, dynamic>{};
    final html = _extractFirstHtml(data);
    final title =
        (workInfo['title'] ?? _extractTitleFromHtml(html) ?? requestedWork)
            .toString();
    final work = (workInfo['work'] ?? requestedWork).toString();
    final content = _htmlToText(html);

    if (content.trim().isEmpty) {
      throw CbetaSendTextException(
        'CBETA returned empty content.',
        result.attempts,
      );
    }

    return CbetaSendText(
      work: work,
      juan: requestedJuan,
      title: title,
      byline: (workInfo['byline'] ?? '').toString(),
      category: (workInfo['category'] ?? workInfo['orig_category'] ?? '')
          .toString(),
      fileName: '${work}_${requestedJuan}_${_safeFileName(title)}.txt',
      content: content,
      sourceUrl: result.url.toString(),
    );
  }

  static Uri _buildCbetaUri(
    String apiRoot,
    String path,
    Map<String, String> params,
  ) {
    final root = apiRoot.replaceFirst(RegExp(r'/+$'), '');
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$root/$cleanPath').replace(queryParameters: params);
  }

  static bool _hasUsableCbetaPayload(String path, Map<String, dynamic> data) {
    if (data['error'] != null) return false;
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    if (!normalizedPath.startsWith('juans')) return true;
    return _extractFirstHtml(data).trim().isNotEmpty;
  }

  static String _describeUnusablePayload(
    String path,
    Map<String, dynamic> data,
  ) {
    if (data['error'] != null) return 'CBETA payload error: ${data['error']}';
    if (path.replaceFirst(RegExp(r'^/+'), '').startsWith('juans')) {
      return 'CBETA returned empty juan content';
    }
    return 'CBETA returned unusable payload';
  }

  static String _extractFirstHtml(Map<String, dynamic> data) {
    final results = data['results'];
    if (results is! List || results.isEmpty) return '';
    final first = results.first;
    if (first is String) return first;
    if (first is Map && first['html'] is String) return first['html'] as String;
    return '';
  }

  static String _htmlToText(String html) {
    if (html.trim().isEmpty) return '';

    final bodyMatch = RegExp(
      r'<body[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(html);
    var source = bodyMatch?.group(1) ?? html;
    source = source
        .replaceAll(
          RegExp(r'''<div[^>]+id=['"]back['"][\s\S]*$''', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'''<span[^>]+class=['"][^'"]*\blb\b[^'"]*['"][^>]*>[\s\S]*?</span>''',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'''<span[^>]+class=['"][^'"]*\blineInfo\b[^'"]*['"][^>]*>[\s\S]*?</span>''',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'''<a[^>]+class=['"][^'"]*\bnoteAnchor\b[^'"]*['"][^>]*>[\s\S]*?</a>''',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'''<a[^>]+class=['"][^'"]*\bfacsimile\b[^'"]*['"][^>]*>[\s\S]*?</a>''',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'<(p|div|br|h[1-6])\b[^>]*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'</(p|div|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    return _decodeHtmlEntities(source)
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _decodeHtmlEntities(String value) {
    const named = {
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
      'nbsp': ' ',
    };

    return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
      match,
    ) {
      final code = match.group(1) ?? '';
      if (code.startsWith('#x') || code.startsWith('#X')) {
        final parsed = int.tryParse(code.substring(2), radix: 16);
        return parsed == null ? match.group(0)! : String.fromCharCode(parsed);
      }
      if (code.startsWith('#')) {
        final parsed = int.tryParse(code.substring(1));
        return parsed == null ? match.group(0)! : String.fromCharCode(parsed);
      }
      return named[code] ?? match.group(0)!;
    });
  }

  static String? _extractTitleFromHtml(String html) {
    final match = RegExp(
      r'<title>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    final title = match?.group(1);
    if (title == null) return null;
    return _decodeHtmlEntities(title.replaceAll(RegExp(r'<[^>]+>'), '')).trim();
  }

  static String _safeFileName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '');
    return safe.length > 80 ? safe.substring(0, 80) : safe;
  }

  static int? _parseCursor(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null) return null;
    return parsed.clamp(0, _defaultSendWorks.length).toInt();
  }

  static Map<String, dynamic> _normalizeError(
    String work,
    int juan,
    Object error,
  ) {
    return {
      'work': work,
      'juan': juan,
      'message': error.toString(),
      if (error is CbetaSendTextException) 'attempts': error.attempts,
    };
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
