import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../dacheng_ai_service.dart';
import '../diagnostic_log_service.dart';
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
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Duration _firstTokenTimeout = Duration(seconds: 120);
  static const Duration _streamIdleTimeout = Duration(seconds: 90);
  static const String _desktopToolSystemPrompt = '''
你是大乘桌面端内置 OpenClaw 助理。用户要求打开浏览器、访问网页、点击页面、输入文本、读取本机桌面或操作 Chrome 时，要优先调用可用的 browser、chrome 或 desktop 工具实际执行，不要只给操作教程。涉及本机桌面或 Chrome 写操作时，大乘会弹出确认，请发起工具调用并等待用户确认。
''';

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
    final requestId = _uuid.v4();
    final totalWatch = Stopwatch()..start();
    final normalizedMessage = message.trim();
    final requiresLocalToolExecution = _requiresLocalToolExecution(
      normalizedMessage,
    );
    String? fallbackConversationId;
    List<Map<String, dynamic>>? fallbackMessages;
    if (normalizedMessage.isEmpty) {
      _diag('chat.skip-empty', data: {'requestId': requestId});
      return;
    }

    try {
      _diag(
        'chat.start',
        data: {
          'requestId': requestId,
          'messageLength': normalizedMessage.length,
          'conversationId': conversationId,
          'hasToken': token != null && token.isNotEmpty,
          'hasUsername': username != null && username.isNotEmpty,
          'isMember': isMember,
        },
      );

      final ensureWatch = Stopwatch()..start();
      final target = await OpenClawRuntime.instance.ensureStarted(
        authToken: token,
        username: username,
        isMember: isMember,
      );
      ensureWatch.stop();
      _diag(
        'chat.runtime-ready',
        data: {
          'requestId': requestId,
          'elapsedMs': ensureWatch.elapsedMilliseconds,
          'baseUri': target.baseUri.toString(),
          'model': target.model,
          'modelOverrideSet': target.modelOverride != null,
          'desktopToolsUri': target.desktopToolsUri?.toString(),
        },
      );

      final effectiveConversationId =
          (conversationId != null && conversationId.trim().isNotEmpty)
          ? conversationId.trim()
          : _newConversationId();
      fallbackConversationId = effectiveConversationId;

      yield DachengAiStreamEvent(
        type: 'step',
        text: '本机 OpenClaw 已接管首页 AI 对话',
        conversationId: effectiveConversationId,
        raw: {
          'title': '本机 OpenClaw',
          'message': '正在处理请求',
          if (target.desktopToolsStatus != null)
            'desktopTools': target.desktopToolsStatus,
        },
      );

      final existing = await _store.get(effectiveConversationId);
      final historyMessages =
          (existing?.messages ?? const <LocalAiConversationMessage>[])
              .where((item) => item.content.trim().isNotEmpty)
              .map(
                (item) => {
                  'role': item.role == 'user' ? 'user' : 'assistant',
                  'content': item.content,
                },
              )
              .toList();
      final userMessage = {'role': 'user', 'content': normalizedMessage};
      final requestMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': _desktopToolSystemPrompt.trim()},
        ...historyMessages,
        userMessage,
      ];
      fallbackMessages = [...historyMessages, userMessage];

      final uri = target.baseUri.replace(path: '/v1/chat/completions');
      final body = jsonEncode({
        'model': target.model,
        'stream': true,
        'stream_options': {'include_usage': true},
        'user': 'dacheng:$effectiveConversationId',
        'messages': requestMessages,
      });
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
        ..body = body;
      _diag(
        'chat.request',
        data: {
          'requestId': requestId,
          'uri': uri.toString(),
          'conversationId': effectiveConversationId,
          'messageCount': requestMessages.length,
          'bodyBytes': utf8.encode(body).length,
          'requiresLocalToolExecution': requiresLocalToolExecution,
        },
      );

      final responseWatch = Stopwatch()..start();
      final response = await _httpClient.send(request).timeout(_requestTimeout);
      responseWatch.stop();
      _diag(
        'chat.response',
        data: {
          'requestId': requestId,
          'statusCode': response.statusCode,
          'elapsedMs': responseWatch.elapsedMilliseconds,
          'contentType': response.headers['content-type'],
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response.stream);
        _diag(
          'chat.response-error',
          data: {
            'requestId': requestId,
            'statusCode': response.statusCode,
            'body': body,
          },
        );
        throw StateError(
          body.trim().isEmpty
              ? '本机 OpenClaw 请求失败 (${response.statusCode})'
              : body,
        );
      }

      var finalText = '';
      DachengAiUsage? usage;
      var sawDone = false;
      var lineCount = 0;
      var dataCount = 0;
      var deltaCount = 0;
      final streamWatch = Stopwatch()..start();

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(
            _streamIdleTimeout,
            onTimeout: (sink) {
              sink.addError(
                TimeoutException(
                  'OpenClaw SSE stream idle for ${_streamIdleTimeout.inSeconds}s',
                ),
              );
              sink.close();
            },
          );

      await for (final line in lines) {
        lineCount++;
        if (finalText.isEmpty && streamWatch.elapsed > _firstTokenTimeout) {
          throw TimeoutException(
            'OpenClaw first token timeout after ${_firstTokenTimeout.inSeconds}s',
          );
        }
        if (!line.startsWith('data:')) continue;
        dataCount++;
        if (dataCount == 1) {
          _diag(
            'chat.first-data',
            data: {
              'requestId': requestId,
              'elapsedMs': streamWatch.elapsedMilliseconds,
              'lineLength': line.length,
            },
          );
        }
        final dataText = line.substring('data:'.length).trim();
        if (dataText.isEmpty) continue;
        if (dataText == '[DONE]') {
          sawDone = true;
          _diag(
            'chat.done-marker',
            data: {
              'requestId': requestId,
              'elapsedMs': streamWatch.elapsedMilliseconds,
              'lineCount': lineCount,
              'dataCount': dataCount,
              'deltaCount': deltaCount,
            },
          );
          break;
        }

        final decoded = _safeDecodeMap(dataText, requestId: requestId);
        if (decoded == null) continue;
        final streamError = _streamErrorMessage(decoded);
        if (streamError != null) {
          _diag(
            'chat.stream-error',
            data: {
              'requestId': requestId,
              'elapsedMs': streamWatch.elapsedMilliseconds,
              'message': _previewText(streamError),
            },
          );
          if (_isDeepSeekBlockedError(streamError)) {
            throw _OpenClawDeepSeekBlockedException(streamError);
          }
          throw StateError(streamError);
        }

        final usageJson = decoded['usage'];
        if (usageJson is Map) {
          usage = DachengAiUsage.fromJson(Map<String, dynamic>.from(usageJson));
        }

        final deltaText = _deltaText(decoded);
        if (deltaText.isEmpty) continue;
        deltaCount++;
        if (deltaCount == 1) {
          _diag(
            'chat.first-delta',
            data: {
              'requestId': requestId,
              'elapsedMs': streamWatch.elapsedMilliseconds,
              'deltaLength': deltaText.length,
            },
          );
        }
        finalText += deltaText;
        yield DachengAiStreamEvent(
          type: 'delta',
          text: deltaText,
          conversationId: effectiveConversationId,
          raw: decoded,
        );
      }

      _diag(
        'chat.stream-finished',
        data: {
          'requestId': requestId,
          'elapsedMs': streamWatch.elapsedMilliseconds,
          'totalElapsedMs': totalWatch.elapsedMilliseconds,
          'lineCount': lineCount,
          'dataCount': dataCount,
          'deltaCount': deltaCount,
          'finalLength': finalText.trim().length,
          'sawDone': sawDone,
        },
      );

      if (finalText.trim().isEmpty) {
        _diag(
          'chat.empty-result',
          data: {'requestId': requestId, 'sawDone': sawDone},
        );
        throw StateError('本机 OpenClaw 返回空结果，请复制诊断日志排查');
      }

      await _store.upsertTurn(
        conversationId: effectiveConversationId,
        userText: normalizedMessage,
        assistantText: finalText.trim(),
      );

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
          if (target.desktopToolsStatus != null)
            'desktopTools': target.desktopToolsStatus,
        },
      );
    } catch (error, stackTrace) {
      if (error is _OpenClawDeepSeekBlockedException &&
          fallbackConversationId != null &&
          fallbackMessages != null &&
          !requiresLocalToolExecution) {
        _diag(
          'chat.backend-fallback.start',
          data: {
            'requestId': requestId,
            'elapsedMs': totalWatch.elapsedMilliseconds,
            'conversationId': fallbackConversationId,
            'messageCount': fallbackMessages.length,
          },
          error: error,
          stackTrace: stackTrace,
        );
        yield* _sendBackendDeepSeekProxyStream(
          requestId: requestId,
          conversationId: fallbackConversationId,
          normalizedMessage: normalizedMessage,
          messages: fallbackMessages,
          token: token,
          username: username,
          isMember: isMember,
          startedAt: totalWatch,
        );
        return;
      }
      if (error is _OpenClawDeepSeekBlockedException &&
          requiresLocalToolExecution) {
        _diag(
          'chat.backend-fallback.skipped-local-tool-request',
          data: {
            'requestId': requestId,
            'elapsedMs': totalWatch.elapsedMilliseconds,
          },
          error: error,
          stackTrace: stackTrace,
        );
        throw StateError('本机 OpenClaw 工具调用失败，未降级为纯文本模型：${error.message}');
      }
      _diag(
        'chat.error',
        data: {
          'requestId': requestId,
          'elapsedMs': totalWatch.elapsedMilliseconds,
          'error': _previewText(error.toString()),
        },
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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

  Stream<DachengAiStreamEvent> _sendBackendDeepSeekProxyStream({
    required String requestId,
    required String conversationId,
    required String normalizedMessage,
    required List<Map<String, dynamic>> messages,
    required Stopwatch startedAt,
    String? token,
    String? username,
    bool isMember = false,
  }) async* {
    final uri = Uri.parse(
      '${AppConfig.currentAiBackendUrl.replaceFirst(RegExp(r'/+$'), '')}'
      '/api/openclaw/deepseek/v1/chat/completions',
    );

    yield DachengAiStreamEvent(
      type: 'step',
      text: '本机 OpenClaw 已启动，DeepSeek 代理正在处理请求',
      conversationId: conversationId,
      raw: {'title': 'DeepSeek 代理', 'message': '正在处理请求'},
    );

    final body = jsonEncode({
      'model': 'deepseek-chat',
      'stream': true,
      'stream_options': {'include_usage': true},
      'messages': messages,
      if (username != null && username.isNotEmpty) 'username': username,
      'clientMembershipHint': isMember,
    });
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer dacheng-openclaw-proxy',
        if (token != null && token.isNotEmpty) 'x-dacheng-auth-token': token,
      })
      ..body = body;

    _diag(
      'chat.backend-fallback.request',
      data: {
        'requestId': requestId,
        'uri': uri.toString(),
        'conversationId': conversationId,
        'messageCount': messages.length,
        'bodyBytes': utf8.encode(body).length,
      },
    );

    final response = await _httpClient
        .send(request)
        .timeout(AppConfig.requestTimeout);
    _diag(
      'chat.backend-fallback.response',
      data: {
        'requestId': requestId,
        'statusCode': response.statusCode,
        'contentType': response.headers['content-type'],
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decodeStream(response.stream);
      throw StateError(body.trim().isEmpty ? 'DeepSeek 代理请求失败' : body);
    }

    var finalText = '';
    DachengAiUsage? usage;
    var sawDone = false;
    var dataCount = 0;
    var deltaCount = 0;
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(_streamIdleTimeout);

    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      dataCount++;
      final dataText = line.substring('data:'.length).trim();
      if (dataText.isEmpty) continue;
      if (dataText == '[DONE]') {
        sawDone = true;
        break;
      }

      final decoded = _safeDecodeMap(dataText, requestId: requestId);
      if (decoded == null) continue;
      final streamError = _streamErrorMessage(decoded);
      if (streamError != null) throw StateError(streamError);

      final usageJson = decoded['usage'];
      if (usageJson is Map) {
        usage = DachengAiUsage.fromJson(Map<String, dynamic>.from(usageJson));
      }

      final deltaText = _deltaText(decoded);
      if (deltaText.isEmpty) continue;
      deltaCount++;
      finalText += deltaText;
      yield DachengAiStreamEvent(
        type: 'delta',
        text: deltaText,
        conversationId: conversationId,
        raw: decoded,
      );
    }

    _diag(
      'chat.backend-fallback.finished',
      data: {
        'requestId': requestId,
        'elapsedMs': startedAt.elapsedMilliseconds,
        'dataCount': dataCount,
        'deltaCount': deltaCount,
        'finalLength': finalText.trim().length,
        'sawDone': sawDone,
      },
    );

    if (finalText.trim().isEmpty) {
      throw StateError('DeepSeek 代理返回空结果，请复制诊断日志排查');
    }

    await _store.upsertTurn(
      conversationId: conversationId,
      userText: normalizedMessage,
      assistantText: finalText.trim(),
    );

    yield DachengAiStreamEvent(
      type: 'done',
      text: finalText.trim(),
      conversationId: conversationId,
      usage: usage ?? _zeroUsage,
      raw: {
        'message': finalText.trim(),
        'conversationId': conversationId,
        'provider': 'openclaw-deepseek-proxy',
        'sawDone': sawDone,
      },
    );
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

  String? _streamErrorMessage(Map<String, dynamic> decoded) {
    final error = decoded['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    if (error is Map) {
      final message = error['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    final type = decoded['type']?.toString();
    if (type == 'error') {
      final message = decoded['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  bool _isDeepSeekBlockedError(String message) {
    return RegExp(
      r'(403|blocked|forbidden|被拦截)',
      caseSensitive: false,
    ).hasMatch(message);
  }

  @visibleForTesting
  bool requiresLocalToolExecutionForTest(String message) {
    return _requiresLocalToolExecution(message);
  }

  bool _requiresLocalToolExecution(String message) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) return false;
    final hasUrl = RegExp(r'https?://|www\.').hasMatch(text);
    final hasAction = RegExp(
      r'(open|visit|navigate|go to|click|tap|type|input|screenshot|browser|chrome|desktop|打开|访问|浏览器|网页|点击|点按|输入|截图|屏幕|桌面|chrome)',
      caseSensitive: false,
    ).hasMatch(text);
    if (hasUrl && hasAction) return true;
    return RegExp(
      r'(打开浏览器|访问网页|打开网页|点击页面|操作浏览器|操作chrome|操作桌面|本机.*点击|桌面.*点击|浏览器.*点击)',
      caseSensitive: false,
    ).hasMatch(text);
  }

  Map<String, dynamic>? _safeDecodeMap(String dataText, {String? requestId}) {
    try {
      final decoded = jsonDecode(dataText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      final logData = <String, Object?>{
        'payloadLength': dataText.length,
        'payloadPrefix': dataText.length > 160
            ? dataText.substring(0, 160)
            : dataText,
      };
      if (requestId != null) {
        logData['requestId'] = requestId;
      }
      _diag('chat.decode-error', data: logData, error: error);
    }
    return null;
  }

  String _previewText(String text) {
    final trimmed = text.trim();
    return trimmed.length <= 300 ? trimmed : trimmed.substring(0, 300);
  }

  DachengAiUsage get _zeroUsage => const DachengAiUsage(
    promptTokens: 0,
    completionTokens: 0,
    totalTokens: 0,
    remainingTokens: 0,
    monthlyLimit: 0,
  );

  void _diag(
    String message, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    unawaited(
      DiagnosticLogService.instance.log(
        'openclaw.chat',
        message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

class _OpenClawDeepSeekBlockedException implements Exception {
  final String message;

  const _OpenClawDeepSeekBlockedException(this.message);

  @override
  String toString() => message;
}
