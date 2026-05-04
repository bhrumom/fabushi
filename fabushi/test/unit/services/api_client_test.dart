import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:global_dharma_sharing/services/api_client.dart';

http.Response jsonResponse(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('legacy services ApiClient', () {
    test('keeps backend message and error key for auth failures', () async {
      final apiClient = ApiClient(
        httpClient: MockClient(
          (_) async => jsonResponse('{"message":"登录已过期"}', 401),
        ),
        baseUrlResolver: () async => 'https://example.com',
      );

      final response = await apiClient.get('/api/auth/user-info', token: 'token');

      expect(response['success'], false);
      expect(response['error'], '登录已过期');
      expect(response['errorKey'], 'INVALID_TOKEN');
      expect(response['statusCode'], 401);
    });

    test('returns success for empty successful responses', () async {
      final apiClient = ApiClient(
        httpClient: MockClient((_) async => http.Response('', 204)),
        baseUrlResolver: () async => 'https://example.com',
      );

      final response = await apiClient.post('/api/auth/logout');

      expect(response['success'], true);
      expect(response['statusCode'], 204);
    });

    test('does not crash when token preview is shorter than 20 chars', () async {
      final apiClient = ApiClient(
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer short');
          return http.Response('{"success":true}', 200);
        }),
        baseUrlResolver: () async => 'https://example.com',
      );

      final response = await apiClient.get('/health', token: 'short');

      expect(response['success'], true);
    });

    test('maps transport failures to network error payloads', () async {
      final apiClient = ApiClient(
        httpClient: MockClient(
          (_) async => throw http.ClientException('socket closed'),
        ),
        baseUrlResolver: () async => 'https://example.com',
      );

      final response = await apiClient.get('/health');

      expect(response['success'], false);
      expect(response['errorKey'], 'NETWORK_ERROR');
      expect(response['error'], isNotEmpty);
    });
  });
}
