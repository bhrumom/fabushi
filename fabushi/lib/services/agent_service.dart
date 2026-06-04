import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

class AgentChatResult {
  final String runId;
  final String conversationId;
  final String? messageId;
  final String? streamUrl;
  final String message;
  final String provider;
  final String model;
  final Map<String, dynamic> usage;

  const AgentChatResult({
    required this.runId,
    required this.conversationId,
    this.messageId,
    this.streamUrl,
    this.message = '',
    this.provider = '',
    this.model = '',
    this.usage = const {},
  });

  factory AgentChatResult.fromJson(Map<String, dynamic> json) {
    return AgentChatResult(
      runId: (json['runId'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      messageId: json['messageId']?.toString(),
      streamUrl: json['streamUrl']?.toString(),
      message: (json['message'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      usage: json['usage'] is Map
          ? Map<String, dynamic>.from(json['usage'] as Map)
          : const {},
    );
  }
}

class AgentStreamEvent {
  final String type;
  final String text;
  final String? runId;
  final String? conversationId;
  final Map<String, dynamic> raw;

  const AgentStreamEvent({
    required this.type,
    required this.text,
    this.runId,
    this.conversationId,
    this.raw = const {},
  });

  bool get isDelta => type == 'assistant.delta';
  bool get isMessage => type == 'assistant.message';
  bool get isCompleted => type == 'run.completed';
  bool get isFailed => type == 'run.failed';
  bool get isCancelled => type == 'run.cancelled';
}

class AgentService {
  AgentService({
    http.Client? httpClient,
    Future<String> Function()? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? (() async => AppConfig.currentBackendUrl);

  final http.Client _httpClient;
  final Future<String> Function() _baseUrl;

  Future<AgentChatResult> sendMessage({
    required String message,
    String? conversationId,
    String? messageId,
    String mode = 'dharma_guide',
    bool stream = false,
    String? token,
    Map<String, dynamic>? client,
  }) async {
    final data = await _postJson(
      '/api/agent/chat',
      token: token,
      body: {
        'message': message,
        'mode': mode,
        'stream': stream,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversationId': conversationId,
        if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
        if (client != null && client.isNotEmpty) 'client': client,
      },
    );
    return AgentChatResult.fromJson(data);
  }

  Stream<AgentStreamEvent> streamRun({
    required String runId,
    String? token,
  }) async* {
    final uri = await _buildUri('/api/agent/runs/$runId/events');
    final request = http.Request('GET', uri)..headers.addAll(_headers(token));
    final response = await _httpClient
        .send(request)
        .timeout(AppConfig.requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decodeStream(response.stream);
      throw StateError(body.trim().isEmpty ? '请求失败' : body);
    }

    String eventName = 'message';
    final dataLines = <String>[];

    AgentStreamEvent? flushEvent() {
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

      return AgentStreamEvent(
        type: currentEvent,
        text:
            (data['text'] ?? data['content'] ?? data['message'] ?? data['summary'] ?? '')
                .toString(),
        runId: data['runId']?.toString(),
        conversationId: data['conversationId']?.toString(),
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

  Future<void> cancelRun({required String runId, String? token}) async {
    await _postJson('/api/agent/runs/$runId/cancel', token: token, body: const {});
  }

  Future<void> submitFeedback({
    required String messageId,
    required String rating,
    String? reason,
    String? comment,
    String? token,
  }) async {
    await _postJson(
      '/api/agent/messages/$messageId/feedback',
      token: token,
      body: {
        'rating': rating,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
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

  Future<Uri> _buildUri(String endpoint) async {
    final configuredBaseUrl = await _baseUrl();
    if (configuredBaseUrl.trim().isNotEmpty) {
      final baseUrl = configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
      return Uri.parse('$baseUrl$endpoint');
    }
    return AppConfig.buildBackendUri(endpoint);
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
    final decoded = body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(body);
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
}
