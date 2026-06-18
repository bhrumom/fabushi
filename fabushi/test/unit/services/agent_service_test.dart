import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:global_dharma_sharing/services/agent_service.dart';

http.Response jsonResponse(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('AgentService', () {
    test('sends chat through the first-party agent endpoint', () async {
      final service = AgentService(
        baseUrl: () async => 'https://api.ombhrum.com',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.ombhrum.com/api/agent/chat');
          expect(request.headers['Authorization'], 'Bearer token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['message'], '今日适合念什么经？');
          expect(body['mode'], 'dharma_guide');
          expect(body['stream'], false);
          return jsonResponse(
            '{"success":true,"runId":"run_1","conversationId":"conv_1","message":"阿弥陀佛"}',
            200,
          );
        }),
      );

      final result = await service.sendMessage(
        message: '今日适合念什么经？',
        token: 'token',
      );

      expect(result.runId, 'run_1');
      expect(result.conversationId, 'conv_1');
      expect(result.message, '阿弥陀佛');
    });

    test('parses agent SSE events', () async {
      final service = AgentService(
        baseUrl: () async => 'https://api.ombhrum.com',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.ombhrum.com/api/agent/runs/run_1/events',
          );
          return http.Response.bytes(
            utf8.encode(
              'event: assistant.delta\n'
              'data: {"text":"阿弥"}\n\n'
              'event: run.completed\n'
              'data: {"usage":{"totalTokens":10}}\n\n',
            ),
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );

      final events = await service.streamRun(runId: 'run_1').toList();

      expect(events, hasLength(2));
      expect(events.first.type, 'assistant.delta');
      expect(events.first.text, '阿弥');
      expect(events.last.isCompleted, true);
    });

    test('calls cancel and feedback endpoints', () async {
      final seen = <String>[];
      final service = AgentService(
        baseUrl: () async => 'https://api.ombhrum.com',
        httpClient: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          return jsonResponse('{"success":true}', 200);
        }),
      );

      await service.cancelRun(runId: 'run_1', token: 'token');
      await service.submitFeedback(
        messageId: 'msg_1',
        rating: 'up',
        reason: 'helpful',
        token: 'token',
      );

      expect(seen, [
        'POST /api/agent/runs/run_1/cancel',
        'POST /api/agent/messages/msg_1/feedback',
      ]);
    });
  });
}
