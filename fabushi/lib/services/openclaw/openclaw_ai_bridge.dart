import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../dacheng_ai_service.dart';
import '../local_ai_conversation_store.dart';
import 'openclaw_runtime.dart';

/// 将现有大乘首页 AI 对话适配到本机 OpenClaw Gateway。
///
/// UI 层仍然使用 DachengAiService；桌面端由 DachengAiService 路由到这里。
/// OpenClaw Gateway 使用 OpenAI-compatible `/v1/chat/completions`，所以本类只负责：
/// 1. 自动启动内置 Gateway；
/// 2. 把现有会话消息转换为 OpenAI Chat 消息；
/// 3. 解析 SSE delta 并转换为 DachengAiStreamEvent；
/// 4. 在本机保存桌面端会话历史。
class OpenClawAiBridge {
  OpenClawAiBridge({http.Client? httpClient, LocalAiConversationStore? store})
    : _httpClient = httpClient ?? http.Client(),
      _store = store ?? LocalAiConversationStore.instance;

  final http.Client _httpClient;
  final LocalAiConversationStore _store;
  static final Uuid _uuid = Uuid();

  Future<DachengAiChatResult> sendChat({
    required String message,
    String? conversationId,
    String? token,
    String? username,
    bool isMember = false,
  }) async {
    String? latestConversationId = conversationId;
    String finalMessage = '';
    DachengAiUsage? usage;

    await for (final event in sendChatStream(
      message: message,
      conversationId: conversationId,
      token: token,
      username: username,
      isMember: isMember,
    )) {
      if (event.conversationId != null && event.conversationId!.isNotEmpty) {
        latestConversationId = event.conversationId;
      }
      if (event.isDelta) {
        finalMessage += event.text;
      } else if (event.isDone) {
        finalMessage = (event.raw['message'] ?? finalMessage).toString();
        usage = event.usage;
      } else if (event.isError) {
        throw StateError(event.text);
      }
    }

    return DachengAiChatResult(
      conversationId: latestConversationId ?? _newConversationId(),
      message: finalMessage,
      provider: 'openclaw-local',
      model: 'openclaw/default',
      usage: usage ?? _zeroUsage,
    );
  }

  Stream<DachengAiStreamEvent> sendChatStream({
    required String message,
    String? conversationId,
    String? token,
    String? username,
    bool isMember = false,
  }) async* {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) return;

    final target = await OpenClawRuntime.instance.ensureStarted(
      authToken: token,
      username: username,
      isMember: isMember,
    );
    final effectiveConversationId =
        (conversationId != null && conversationId.trim().isNotEmpty)
        ? conversationId.trim()
        : _newConversationId();

    yield DachengAiStreamEvent(
      type: 'step',
      text: '本机 OpenClaw 已接管首页 AI 对话',
      conversationId: effectiveConversationId,
      raw: const {'title': '本机 OpenClaw', 'message': '正在处理请求'},
    );

    final existing = await _store.get(effectiveConversationId);
    final requestMessages = <Map<String, dynamic>>[
      ...(existing?.messages ?? const <LocalAiConversationMessage>[])
          .where((item) => item.content.trim().isNotEmpty)
          .map(
            (item) => {
              'role': item.role == 'user' ? 'user' : 'assistant',
              'content': item.content,
            },
          ),
      {'role': 'user', 'content': normalizedMessage},
    ];

    final uri = target.baseUri.replace(path: '/v1/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${target.token}',
        if (target.modelOverride != null)
          'x-openclaw-model': target.modelOverride!,
        'x-openclaw-session-key': 'dacheng:$effectiveConversationId',
        'x-openclaw-message-channel': 'dacheng-desktop',
      })
      ..body = jsonEncode({
        'model': target.model,
        'stream': true,
        'stream_options': {'include_usage': true},
        'user': 'dacheng:$effectiveConversationId',
        'messages': requestMessages,
      });

    final response = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decodeStream(response.stream);
      throw StateError(
        body.trim().isEmpty
            ? '本机 OpenClaw 请求失败 (${response.statusCode})'
            : body,
      );
    }

    var finalText = '';
    DachengAiUsage? usage;
    var sawDone = false;

    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final dataText = line.substring('data:'.length).trim();
      if (dataText.isEmpty) continue;
      if (dataText == '[DONE]') {
        sawDone = true;
        break;
      }

      final decoded = _safeDecodeMap(dataText);
      if (decoded == null) continue;

      final usageJson = decoded['usage'];
      if (usageJson is Map) {
        usage = DachengAiUsage.fromJson(Map<String, dynamic>.from(usageJson));
      }

      final deltaText = _deltaText(decoded);
      if (deltaText.isEmpty) continue;
      finalText += deltaText;
      yield DachengAiStreamEvent(
        type: 'delta',
        text: deltaText,
        conversationId: effectiveConversationId,
        raw: decoded,
      );
    }

    if (finalText.trim().isNotEmpty) {
      await _store.upsertTurn(
        conversationId: effectiveConversationId,
        userText: normalizedMessage,
        assistantText: finalText.trim(),
      );
    }

    yield DachengAiStreamEvent(
      type: 'done',
      text: finalText.trim(),
      conversationId: effectiveConversationId,
      usage: usage ?? _zeroUsage,
      raw: {
        'message': finalText.trim(),
        'conversationId': effectiveConversationId,
        'provider': 'openclaw-local',
        'sawDone': sawDone,
      },
    );
  }

  Future<List<DachengConversationSummary>> listConversations() async {
    final items = await _store.list();
    return items
        .map(
          (item) => DachengConversationSummary(
            id: item.id,
            title: item.title,
            updatedAt: item.updatedAt,
          ),
        )
        .toList();
  }

  Future<List<DachengConversationMessage>> getConversationMessages({
    required String conversationId,
  }) async {
    final item = await _store.get(conversationId);
    if (item == null) return const [];
    return item.messages
        .where((message) => message.content.trim().isNotEmpty)
        .map(
          (message) => DachengConversationMessage(
            role: message.role,
            content: message.content,
          ),
        )
        .toList();
  }

  String _newConversationId() => 'local-${_uuid.v4()}';

  String _deltaText(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final choice = Map<String, dynamic>.from(first);
    final delta = choice['delta'];
    if (delta is Map && delta['content'] != null) {
      return delta['content'].toString();
    }
    final message = choice['message'];
    if (message is Map && message['content'] != null) {
      return message['content'].toString();
    }
    return '';
  }

  Map<String, dynamic>? _safeDecodeMap(String dataText) {
    try {
      final decoded = jsonDecode(dataText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  DachengAiUsage get _zeroUsage => const DachengAiUsage(
    promptTokens: 0,
    completionTokens: 0,
    totalTokens: 0,
    remainingTokens: 0,
    monthlyLimit: 0,
  );
}
