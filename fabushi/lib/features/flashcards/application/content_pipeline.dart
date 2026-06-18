import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../data/flashcard_repository.dart';
import '../domain/flashcard_models.dart';

class ContentInput {
  final String text;
  final String? url;
  final String title;
  final String sourceApp;
  final String mimeType;
  final String sourceType;

  const ContentInput({
    this.text = '',
    this.url,
    this.title = '',
    this.sourceApp = '',
    this.mimeType = '',
    this.sourceType = 'composer_text',
  });
}

class ContentPipeline {
  ContentPipeline({
    required FlashcardRepository repository,
    http.Client? httpClient,
    this.textLongThresholdChars = 1200,
    this.linkLongThresholdChars = 1800,
  }) : _repository = repository,
       _httpClient = httpClient ?? http.Client();

  final FlashcardRepository _repository;
  final http.Client _httpClient;
  final int textLongThresholdChars;
  final int linkLongThresholdChars;

  Future<PreparedContent> prepare(ContentInput input) async {
    final normalizedUrl = _normalizeUrl(input.url) ?? _firstHttpUrl(input.text);
    final text = input.text.trim();

    if (normalizedUrl != null && text.length < linkLongThresholdChars) {
      try {
        return await _prepareUrl(input, normalizedUrl);
      } catch (e) {
        if (text.length >= 20) {
          return _prepareText(
            input,
            text,
            title: input.title.trim().isEmpty ? '链接摘录' : input.title.trim(),
            sourceUrl: normalizedUrl,
            errorMessage: '链接正文提取失败，已改用分享文本：$e',
          );
        }
        return _failedContent(input, normalizedUrl, e.toString());
      }
    }

    if (text.trim().isEmpty) {
      return _failedContent(input, normalizedUrl, '请输入链接或至少 20 个字的正文。');
    }
    return _prepareText(input, text, sourceUrl: normalizedUrl);
  }

  Future<PreparedContent> _prepareUrl(ContentInput input, String url) async {
    final uri = Uri.parse(url);
    final response = await _httpClient
        .get(
          uri,
          headers: const {
            'Accept': 'text/html,text/plain,application/xhtml+xml',
            'User-Agent': 'FabushiApp/FlashcardContentPipeline',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode}');
    }

    final body = _decodeBody(response);
    final title = _extractTitle(body).trim().isNotEmpty
        ? _extractTitle(body).trim()
        : (input.title.trim().isEmpty ? uri.host : input.title.trim());
    final readable = _extractReadableText(body);
    if (readable.length < 20) {
      throw StateError('正文过短或网页暂不可读');
    }
    return _prepareText(
      input,
      readable,
      title: title,
      sourceUrl: url,
      sourceType: 'composer_url',
    );
  }

  PreparedContent _prepareText(
    ContentInput input,
    String text, {
    String? title,
    String? sourceUrl,
    String? sourceType,
    String? errorMessage,
  }) {
    final cleaned = _cleanText(text);
    if (cleaned.length < 20) {
      return _failedContent(input, sourceUrl, '内容过短，请至少输入 20 个字或 2 句话。');
    }

    final effectiveTitle = _normalizeTitle(
      title ?? input.title,
      fallback: sourceUrl != null ? '链接内容' : '背诵内容',
    );
    final source = ContentSource(
      id: flashcardId('source'),
      sourceType: sourceType ?? input.sourceType,
      rawText: cleaned,
      url: sourceUrl,
      title: effectiveTitle,
      sourceApp: input.sourceApp.trim(),
      mimeType: input.mimeType.trim(),
      receivedAt: DateTime.now(),
      rawTextHash: sha1.convert(utf8.encode(cleaned)).toString(),
    );
    final isLong =
        cleaned.length >=
        (sourceUrl == null ? textLongThresholdChars : linkLongThresholdChars);
    final summary = summarizeText(cleaned, maxLength: isLong ? 160 : 120);
    final previewText = summarizeText(cleaned, maxLength: isLong ? 220 : 480);

    ContentDocument? document;
    if (isLong) {
      document = ContentDocument(
        id: flashcardId('doc'),
        sourceId: source.id,
        title: effectiveTitle,
        summary: summary,
        fullText: cleaned,
        charCount: cleaned.runes.length,
        tokenCount: estimateTokenCount(cleaned),
        language: _looksChinese(cleaned) ? 'zh' : 'mixed',
        extractedAt: DateTime.now(),
        sourceUrl: sourceUrl,
      );
      unawaited(_repository.saveDocument(document));
    }

    return PreparedContent(
      source: source,
      document: document,
      title: effectiveTitle,
      text: cleaned,
      summary: summary,
      previewText: previewText,
      isLong: isLong,
      errorMessage: errorMessage,
    );
  }

  PreparedContent _failedContent(
    ContentInput input,
    String? sourceUrl,
    String errorMessage,
  ) {
    final source = ContentSource(
      id: flashcardId('source_failed'),
      sourceType: input.sourceType,
      rawText: input.text.trim(),
      url: sourceUrl,
      title: _normalizeTitle(input.title, fallback: '待处理内容'),
      sourceApp: input.sourceApp,
      mimeType: input.mimeType,
      receivedAt: DateTime.now(),
      rawTextHash: sha1.convert(utf8.encode(input.text.trim())).toString(),
    );
    return PreparedContent(
      source: source,
      title: source.title,
      text: input.text.trim(),
      summary: '内容提取失败',
      previewText: errorMessage,
      isLong: false,
      isFailed: true,
      errorMessage: errorMessage,
    );
  }

  static String summarizeText(String text, {int maxLength = 160}) {
    final cleaned = _cleanText(text);
    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength).trim()}...';
  }

  static int estimateTokenCount(String text) {
    final chineseCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(text).length;
    final latinWords = RegExp(r'[A-Za-z0-9_]+').allMatches(text).length;
    return chineseCount + latinWords;
  }

  static String? firstHttpUrl(String text) => _firstHttpUrl(text);

  static String _decodeBody(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().contains('charset=utf-8')) {
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    }
    try {
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return response.body;
    }
  }

  static String _extractTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return '';
    return _decodeHtmlEntities(_stripTags(match.group(1) ?? '')).trim();
  }

  static String _extractReadableText(String html) {
    var text = html
        .replaceAll(
          RegExp(
            r'<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<style[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<noscript[^>]*>.*?</noscript>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'</(?:p|div|section|article|br|li|h\d)>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _decodeHtmlEntities(text);
    return _cleanText(text);
  }

  static String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), ' ');

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1) ?? '');
          if (code == null) return match.group(0) ?? '';
          return String.fromCharCode(code);
        });
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[\t\f\v ]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String? _firstHttpUrl(String text) {
    final match = RegExp(
      r'https?://[^\s，。、《》【】<>]+',
      caseSensitive: false,
    ).firstMatch(text.trim());
    return match?.group(0)?.replaceAll(RegExp(r'[，。、,.)）\]】>》]+$'), '').trim();
  }

  static String? _normalizeUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https'))
      return null;
    return uri.toString();
  }

  static String _normalizeTitle(String raw, {required String fallback}) {
    final title = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return fallback;
    if (title.length <= 40) return title;
    return title.substring(0, 40).trim();
  }

  static bool _looksChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }
}
