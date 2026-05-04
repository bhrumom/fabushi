import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:global_dharma_sharing/core/errors/exceptions.dart';
import 'package:global_dharma_sharing/core/network/api_client.dart';

http.Response jsonResponse(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('ApiClient', () {
    test('adds bearer token to outgoing requests', () async {
      final apiClient = ApiClient(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test_token');
          expect(request.headers['Content-Type'], 'application/json');
          return http.Response('{}', 200);
        }),
      );

      apiClient.setToken('test_token');
      await apiClient.get('/health');
    });

    test('returns decoded json for successful responses', () async {
      final apiClient = ApiClient(
        client: MockClient(
          (_) async => http.Response('{"user":{"username":"tester"}}', 200),
        ),
      );

      final response = await apiClient.get('/api/auth/user-info');

      expect(response['user']['username'], 'tester');
    });

    test('returns empty map for successful empty responses', () async {
      final apiClient = ApiClient(
        client: MockClient((_) async => http.Response('', 204)),
      );

      final response = await apiClient.post('/api/auth/logout', {});

      expect(response, isEmpty);
    });

    test('preserves auth failures from the backend', () async {
      final apiClient = ApiClient(
        client: MockClient(
          (_) async => jsonResponse('{"message":"登录已过期"}', 401),
        ),
      );

      expect(
        () => apiClient.get('/api/auth/user-info'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            '登录已过期',
          ),
        ),
      );
    });

    test('maps validation responses to ValidationException', () async {
      final apiClient = ApiClient(
        client: MockClient(
          (_) async => jsonResponse('{"error":"验证码无效"}', 422),
        ),
      );

      expect(
        () => apiClient.post('/api/auth/register', {'code': 'bad'}),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            '验证码无效',
          ),
        ),
      );
    });

    test('maps server failures to ServerException', () async {
      final apiClient = ApiClient(
        client: MockClient(
          (_) async => jsonResponse('{"message":"服务暂时不可用"}', 503),
        ),
      );

      expect(
        () => apiClient.get('/api/auth/user-info'),
        throwsA(
          isA<ServerException>().having(
            (error) => error.message,
            'message',
            '服务暂时不可用',
          ),
        ),
      );
    });

    test('maps transport failures to NetworkException', () async {
      final apiClient = ApiClient(
        client: MockClient(
          (_) async => throw http.ClientException('socket closed'),
        ),
      );

      expect(
        () => apiClient.get('/health'),
        throwsA(
          isA<NetworkException>().having(
            (error) => error.message,
            'message',
            'socket closed',
          ),
        ),
      );
    });
  });
}
