import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import 'ai_backend_policy.dart';
import 'diagnostic_log_service.dart';
import 'openclaw/openclaw_ai_bridge.dart';

class DachengAiUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int remainingTokens;
  final int monthlyLimit;

  const DachengAiUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.remainingTokens,
    required this.monthlyLimit,
  });

  factory DachengAiUsage.fromJson(Map<String, dynamic> json) {
    return DachengAiUsage(
      promptTokens: _readAnyInt(json, const [
        'promptTokens',
        'prompt_tokens',
        'inputTokens',
        'input_tokens',
      ]),
      completionTokens: _readAnyInt(json, const [
        'completionTokens',
        'completion_tokens',
        'outputTokens',
        'output_tokens',
      ]),
      totalTokens: _readAnyInt(json, const ['totalTokens', 'total_tokens']),
      remainingTokens: _readAnyInt(json, const [
        'remainingTokens',
        'remaining_tokens',
      ]),
      monthlyLimit: _readAnyInt(json, const ['monthlyLimit', 'monthly_limit']),
    );
  }
}

class DachengAiChatResult {
  final String conversationId;
  final String message;
  final String provider;
  final String model;
  final DachengAiUsage usage;

  const DachengAiChatResult({
    required this.conversationId,
    required this.message,
    required this.provider,
    required this.model,
    required this.usage,
  });

  factory DachengAiChatResult.fromJson(Map<String, dynamic> json) {
    return DachengAiChatResult(
      conversationId: (json['conversationId'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      provider: (json['provider'] ?? 'deepseek').toString(),
      model: (json['model'] ?? 'deepseek-chat').toString(),
      usage: DachengAiUsage.fromJson(_readMap(json['usage'])),
    );
  }
}

class DachengConversationSummary {
  final String id;
  final String title;
  final DateTime updatedAt;

  const DachengConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory DachengConversationSummary.fromJson(Map<String, dynamic> json) {
    return DachengConversationSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '新对话').toString(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DachengConversationMessage {
  final String role;
  final String content;

  const DachengConversationMessage({required this.role, required this.content});

  factory DachengConversationMessage.fromJson(Map<String, dynamic> json) {
    return DachengConversationMessage(
      role: (json['role'] ?? 'assistant').toString(),
      content: (json['content'] ?? '').toString(),
    );
  }
}

class DharmaResourceSearchResult {
  final String id;
  final String title;
  final String sourceName;
  final String url;
  final String snippet;
  final String resourceType;
  final String? work;
  final int? juan;

  const DharmaResourceSearchResult({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.url,
    required this.snippet,
    required this.resourceType,
    this.work,
    this.juan,
  });

  factory DharmaResourceSearchResult.fromJson(Map<String, dynamic> json) {
    return DharmaResourceSearchResult(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '未命名资源').toString(),
      sourceName: (json['sourceName'] ?? '资源库').toString(),
      url: (json['url'] ?? '').toString(),
      snippet: (json['snippet'] ?? '').toString(),
      resourceType: (json['resourceType'] ?? 'text').toString(),
      work: json['work']?.toString(),
      juan: _readOptionalInt(json['juan']),
    );
  }
}

class DharmaResourceContent {
  final String title;
  final String url;
  final String sourceName;
  final String contentText;
  final String fileName;

  const DharmaResourceContent({
    required this.title,
    required this.url,
    required this.sourceName,
    required this.contentText,
    required this.fileName,
  });

  factory DharmaResourceContent.fromJson(Map<String, dynamic> json) {
    return DharmaResourceContent(
      title: (json['title'] ?? '法布施资源').toString(),
      url: (json['url'] ?? '').toString(),
      sourceName: (json['sourceName'] ?? '资源库').toString(),
      contentText: (json['contentText'] ?? '').toString(),
      fileName: (json['fileName'] ?? 'dharma-resource.txt').toString(),
    );
  }
}

class DachengAiStreamEvent {
  final String type;
  final String text;
  final String? conversationId;
  final DachengAiUsage? usage;
  final Map<String, dynamic> raw;

  const DachengAiStreamEvent({
    required this.type,
    required this.text,
    this.conversationId,
    this.usage,
    this.raw = const {},
  });

  bool get isStep => type == 'step';
  bool get isDelta => type == 'delta';
  bool get isDone => type == 'done';
  bool get isError => type == 'error';
}

class DachengAiService {
  DachengAiService({
    http.Client? httpClient,
    Future<String> Function()? baseUrl,
    OpenClawAiBridge? openClawBridge,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? (() async => AppConfig.currentAiBackendUrl),
       _openClawBridge = openClawBridge ?? OpenClawAiBridge();

  final http.Client _httpClient;
  final Future<String> Function() _baseUrl;
  final OpenClawAiBridge _openClawBridge;

  Future<DachengAiChatResult> sendChat({
    required String message,
    String? conversationId,
    String? token,
    String? username,
    bool isMember = false,
  }) async {
    if (await AiBackendPolicy.shouldUseEmbeddedOpenClaw(isMember: isMember)) {
      return _openClawBridge.sendChat(
        message: message,
        conversationId: conversationId,
        token: token,
        username: username,
        isMember: isMember,
      );
    }

    final data = await _postJson(
      '/api/ai/chat',
      token: token,
      body: {
        'message': message,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversationId': conversationId,
        if (username != null && username.isNotEmpty) 'username': username,
        'clientMembershipHint': isMember,
      },
    );
    return DachengAiChatResult.fromJson(data);
  }

  Stream<DachengAiStreamEvent> sendChatStream({
    required String message,
    String? conversationId,
    String? token,
    String? username,
    bool isMember = false,
  }) async* {
    final useEmbedded = await AiBackendPolicy.shouldUseEmbeddedOpenClaw(
      isMember: isMember,
    );
    _diag(
      'stream.route',
      data: {
        'useEmbeddedOpenClaw': useEmbedded,
        'messageLength': message.trim().length,
        'conversationId': conversationId,
      },
    );
    if (useEmbedded) {
      yield* _openClawBridge.sendChatStream(
        message: message,
        conversationId: conversationId,
        token: token,
        username: username,
        isMember: isMember,
      );
      return;
    }

    final uri = await _buildUri('/api/ai/chat/stream');
    _diag(
      'cloud.stream.request',
      data: {'uri': uri.toString(), 'conversationId': conversationId},
    );
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers(token))
      ..body = jsonEncode({
        'message': message,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversationId': conversationId,
        if (username != null && username.isNotEmpty) 'username': username,
        'clientMembershipHint': isMember,
      });

    final response = await _httpClient
        .send(request)
        .timeout(AppConfig.requestTimeout);
    _diag(
      'cloud.stream.response',
      data: {
        'statusCode': response.statusCode,
        'contentType': response.headers['content-type'],
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decodeStream(response.stream);
      _diag(
        'cloud.stream.response-error',
        data: {'statusCode': response.statusCode, 'body': body},
      );
      throw StateError(body.trim().isEmpty ? '请求失败' : body);
    }

    String eventName = 'message';
    final dataLines = <String>[];

    DachengAiStreamEvent? flushEvent() {
      if (dataLines.isEmpty) return null;
      final dataText = dataLines.join('\n');
      dataLines.clear();
      final currentEvent = eventName;
      eventName = 'message';

      Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(dataText);
        data = decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);
      } catch (_) {
        data = {'text': dataText};
      }

      final text =
          (data['text'] ??
                  data['message'] ??
                  data['title'] ??
                  data['stage'] ??
                  '')
              .toString();
      return DachengAiStreamEvent(
        type: currentEvent,
        text: text,
        conversationId: data['conversationId']?.toString(),
        usage: data['usage'] is Map
            ? DachengAiUsage.fromJson(Map<String, dynamic>.from(data['usage']))
            : null,
        raw: data,
      );
    }

    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        final event = flushEvent();
        if (event != null) yield event;
        continue;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trim());
      }
    }

    final event = flushEvent();
    if (event != null) yield event;
  }

  Future<List<DachengConversationSummary>> listConversations({
    String? token,
    String? username,
    bool isMember = false,
  }) async {
    if (await AiBackendPolicy.shouldUseEmbeddedOpenClaw(isMember: isMember)) {
      return _openClawBridge.listConversations();
    }

    final data = await _getJson(
      '/api/ai/conversations',
      token: token,
      query: {
        if (username != null && username.isNotEmpty) 'username': username,
      },
    );
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => DachengConversationSummary.fromJson(Map.from(item)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<DachengConversationMessage>> getConversationMessages({
    required String conversationId,
    String? token,
    bool isMember = false,
  }) async {
    if (await AiBackendPolicy.shouldUseEmbeddedOpenClaw(isMember: isMember)) {
      return _openClawBridge.getConversationMessages(
        conversationId: conversationId,
      );
    }

    final data = await _getJson(
      '/api/ai/conversations/$conversationId',
      token: token,
    );
    final items = data['messages'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => DachengConversationMessage.fromJson(Map.from(item)))
        .where((item) => item.content.trim().isNotEmpty)
        .toList();
  }

  Future<List<DharmaResourceSearchResult>> searchResources({
    required String query,
    String? token,
  }) async {
    final data = await _postJson(
      '/api/resources/search',
      token: token,
      body: {'query': query, 'limit': 12},
    );
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => DharmaResourceSearchResult.fromJson(Map.from(item)))
        .where((item) => item.url.isNotEmpty)
        .toList();
  }

  Future<DharmaResourceContent> downloadResource({
    required DharmaResourceSearchResult resource,
    String? token,
  }) async {
    final data = await _postJson(
      '/api/resources/download',
      token: token,
      body: {
        'url': resource.url,
        'title': resource.title,
        'sourceName': resource.sourceName,
        if (resource.work != null) 'work': resource.work,
        if (resource.juan != null) 'juan': resource.juan,
      },
    );
    return DharmaResourceContent.fromJson(data);
  }

  Future<Map<String, dynamic>> _getJson(
    String endpoint, {
    String? token,
    Map<String, String>? query,
  }) async {
    final uri = await _buildUri(endpoint, query: query);
    final response = await _httpClient
        .get(uri, headers: _headers(token))
        .timeout(AppConfig.requestTimeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String endpoint, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final uri = await _buildUri(endpoint);
    final response = await _httpClient
        .post(uri, headers: _headers(token), body: jsonEncode(body))
        .timeout(AppConfig.requestTimeout);
    return _decodeResponse(response);
  }

  Future<Uri> _buildUri(String endpoint, {Map<String, String>? query}) async {
    final baseUrl = (await _baseUrl()).replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl$endpoint');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers(String? token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final decoded = body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('后端返回格式异常');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'] ?? decoded['error'] ?? '请求失败';
      throw StateError(message.toString());
    }
    if (decoded['success'] == false) {
      final message = decoded['message'] ?? decoded['error'] ?? '请求失败';
      throw StateError(message.toString());
    }
    return decoded;
  }

  void _diag(
    String message, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    unawaited(
      DiagnosticLogService.instance.log(
        'dacheng.ai',
        message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

int _readAnyInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _readOptionalInt(json[key]);
    if (value != null) return value;
  }
  return 0;
}

int? _readOptionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
