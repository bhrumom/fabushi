import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:global_dharma_sharing/services/social_service.dart';

http.Response jsonResponse(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class FakeSocialHttpClient implements SocialHttpClient {
  FakeSocialHttpClient({this.getResponse, this.postResponse});

  final http.Response? getResponse;
  final http.Response? postResponse;

  @override
  Future<http.Response> get(
    String url, {
    Map<String, String>? queryParams,
    bool useAuth = false,
  }) async {
    return getResponse ?? http.Response('', 500);
  }

  @override
  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) async {
    return postResponse ?? http.Response('', 500);
  }
}

void main() {
  group('SocialService', () {
    test('toggleFollow preserves backend auth failures', () async {
      final service = SocialService.withClient(
        FakeSocialHttpClient(
          postResponse: jsonResponse(
            '{"message":"登录已过期","errorKey":"INVALID_TOKEN"}',
            401,
          ),
        ),
      );

      final response = await service.toggleFollow('alice');

      expect(response, isNotNull);
      expect(response!['success'], false);
      expect(response['error'], '登录已过期');
      expect(response['statusCode'], 401);
      expect(response['errorKey'], 'INVALID_TOKEN');
    });

    test('fetchFollowSummary preserves backend validation failures', () async {
      final service = SocialService.withClient(
        FakeSocialHttpClient(
          getResponse: jsonResponse(
            '{"error":"用户名不存在","errorKey":"VALIDATION_ERROR"}',
            422,
          ),
        ),
      );

      final response = await service.fetchFollowSummary(username: 'missing');

      expect(response['success'], false);
      expect(response['error'], '用户名不存在');
      expect(response['statusCode'], 422);
      expect(response['errorKey'], 'VALIDATION_ERROR');
    });

    test('fetchFollowList returns empty list for malformed response bodies', () async {
      final service = SocialService.withClient(
        FakeSocialHttpClient(getResponse: http.Response('upstream unavailable', 503)),
      );

      final response = await service.fetchFollowList(type: 'followers');

      expect(response, isEmpty);
    });

    test('fetchPracticePrivacy falls back to defaults for invalid responses', () async {
      final service = SocialService.withClient(
        FakeSocialHttpClient(getResponse: jsonResponse('{"success":true}', 200)),
      );

      final response = await service.fetchPracticePrivacy();

      expect(response['isPrivate'], false);
      expect(response['showPracticeName'], true);
      expect(response['showDuration'], true);
      expect(response['showChantCount'], true);
    });

    test('updatePracticePrivacy returns true when backend reports success', () async {
      final service = SocialService.withClient(
        FakeSocialHttpClient(postResponse: jsonResponse('{"success":true}', 200)),
      );

      final response = await service.updatePracticePrivacy(
        isPrivate: true,
        showPracticeName: false,
        showDuration: false,
        showChantCount: true,
      );

      expect(response, true);
    });
  });
}
