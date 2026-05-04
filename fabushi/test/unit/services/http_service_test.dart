import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:global_dharma_sharing/services/http_service.dart';

void main() {
  group('HttpService helpers', () {
    test('prefers backend error message from json response', () {
      final response = http.Response.bytes(
        utf8.encode('{"error":"验证码已过期"}'),
        422,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

      expect(HttpService.getErrorMessage(response), '验证码已过期');
    });

    test('falls back to plain text body when response is not json', () {
      final response = http.Response('upstream unavailable', 503);

      expect(HttpService.getErrorMessage(response), 'upstream unavailable');
    });

    test('returns explicit message for empty response body', () {
      final response = http.Response('', 500);

      expect(HttpService.getErrorMessage(response), '服务器返回空响应');
    });

    test('treats empty successful body as empty map data', () {
      final response = http.Response('', 204);

      final result = HttpService.handleApiResponse(response);

      expect(result['success'], true);
      expect(result['statusCode'], 204);
      expect(result['data'], isEmpty);
    });
  });
}
