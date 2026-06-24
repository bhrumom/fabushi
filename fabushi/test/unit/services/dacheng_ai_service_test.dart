import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:global_dharma_sharing/services/ai_backend_policy.dart';
import 'package:global_dharma_sharing/services/dacheng_ai_service.dart';

http.Response textResponse(
  String body,
  int statusCode, {
  String contentType = 'text/plain; charset=utf-8',
}) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': contentType},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory diagnosticsDir;

  setUpAll(() {
    diagnosticsDir = Directory.systemTemp.createTempSync(
      'dacheng-ai-service-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return diagnosticsDir.path;
          }
          return null;
        });
  });

  tearDownAll(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await diagnosticsDir.exists()) {
      await diagnosticsDir.delete(recursive: true);
    }
  });

  group('DachengAiService', () {
    setUp(() {
      AiBackendPolicy.debugIsDesktopNativeOverride = false;
    });

    tearDown(() {
      AiBackendPolicy.debugIsDesktopNativeOverride = null;
    });

    test('hides Cloudflare HTML from non-stream chat errors', () async {
      final service = DachengAiService(
        baseUrl: () async => 'https://ai.ombhrum.com',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://ai.ombhrum.com/api/ai/chat');
          return textResponse(
            '<!doctype html><title>Cloudflare Tunnel error</title>'
            '<div id="cf-error-details">error code: 1033</div>',
            530,
            contentType: 'text/html; charset=UTF-8',
          );
        }),
      );

      await expectLater(
        service.sendChat(message: 'hi'),
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('大乘 AI 后端暂时不可用，请稍后重试。') &&
                !error.toString().contains('<!doctype html>') &&
                !error.toString().contains('Cloudflare Tunnel error'),
          ),
        ),
      );
    });

    test('hides Cloudflare tunnel text from stream chat errors', () async {
      final service = DachengAiService(
        baseUrl: () async => 'https://ai.ombhrum.com',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://ai.ombhrum.com/api/ai/chat/stream',
          );
          return textResponse('error code: 1033', 530);
        }),
      );

      await expectLater(
        service.sendChatStream(message: 'hi').toList(),
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('大乘 AI 后端暂时不可用，请稍后重试。') &&
                !error.toString().contains('error code: 1033'),
          ),
        ),
      );
    });

    test('uses JSON error message when the backend returns one', () async {
      final service = DachengAiService(
        baseUrl: () async => 'https://ai.ombhrum.com',
        httpClient: MockClient((request) async {
          return textResponse(
            '{"success":false,"message":"今日额度已用完"}',
            429,
            contentType: 'application/json; charset=utf-8',
          );
        }),
      );

      await expectLater(
        service.sendChatStream(message: 'hi').toList(),
        throwsA(
          predicate((Object error) => error.toString().contains('今日额度已用完')),
        ),
      );
    });
  });
}
