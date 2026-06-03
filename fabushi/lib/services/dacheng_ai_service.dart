import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

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
      promptTokens: _readInt(json['promptTokens']),
      completionTokens: _readInt(json['completionTokens']),
      totalTokens: _readInt(json['totalTokens']),
      remainingTokens: _readInt(json['remainingTokens']),
      monthlyLimit: _readInt(json['monthlyLimit']),
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

class DachengAiService {
  DachengAiService({
    http.Client? httpClient,
    Future<String> Function()? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? (() async => AppConfig.currentAiBackendUrl);

  final http.Client _httpClient;
  final Future<String> Function() _baseUrl;

  Future<DachengAiChatResult> sendChat({
    required String message,
    String? conversationId,
    String? token,
    String? username,
    bool isMember = false,
  }) async {
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

  Future<List<DachengConversationSummary>> listConversations({
    String? token,
    String? username,
  }) async {
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
  }) async {
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
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

int _readInt(Object? value) => _readOptionalInt(value) ?? 0;

int? _readOptionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
