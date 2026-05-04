import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:global_dharma_sharing/models/comment_model.dart';
import 'package:global_dharma_sharing/services/comment_service.dart';

http.Response jsonResponse(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class FakeCommentHttpClient implements CommentHttpClient {
  FakeCommentHttpClient({
    this.getResponse,
    this.postResponse,
    this.deleteResponse,
    this.onGet,
    this.onPost,
    this.onDelete,
  });

  final http.Response? getResponse;
  final http.Response? postResponse;
  final http.Response? deleteResponse;
  final void Function(String url)? onGet;
  final void Function(
    String url,
    Map<String, dynamic>? body,
    bool useAuth,
  )? onPost;
  final void Function(String url, bool useAuth)? onDelete;

  @override
  Future<http.Response> get(
    String url, {
    Map<String, String>? queryParams,
    bool useAuth = false,
  }) async {
    onGet?.call(url);
    return getResponse ?? http.Response('', 500);
  }

  @override
  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) async {
    onPost?.call(url, body, useAuth);
    return postResponse ?? http.Response('', 500);
  }

  @override
  Future<http.Response> delete(
    String url, {
    bool useAuth = false,
  }) async {
    onDelete?.call(url, useAuth);
    return deleteResponse ?? http.Response('', 500);
  }
}

void main() {
  group('CommentService', () {
    test('fetchCommentCounts updates cache from valid response payload', () async {
      final service = CommentService.withDependencies(
        httpClient: FakeCommentHttpClient(
          postResponse: jsonResponse(
            '{"counts":{"content-a":3,"content-b":0,"ignored":"oops"}}',
            200,
          ),
        ),
      );

      await service.fetchCommentCounts(['content-a', 'content-b']);

      expect(service.getCommentCount('content-a'), 3);
      expect(service.getCommentCount('content-b'), 0);
      expect(service.getCommentCount('ignored'), 0);
    });

    test('getComments returns empty list for malformed response bodies', () async {
      final service = CommentService.withDependencies(
        httpClient: FakeCommentHttpClient(
          getResponse: http.Response('upstream unavailable', 503),
        ),
      );

      final comments = await service.getComments('content-a');

      expect(comments, isEmpty);
    });

    test('postComment preserves backend validation failures', () async {
      Map<String, dynamic>? capturedBody;
      bool? capturedUseAuth;

      final service = CommentService.withDependencies(
        httpClient: FakeCommentHttpClient(
          postResponse: jsonResponse(
            '{"message":"评论内容过长","errorKey":"VALIDATION_ERROR"}',
            422,
          ),
          onPost: (url, body, useAuth) {
            capturedBody = body;
            capturedUseAuth = useAuth;
          },
        ),
        mainPracticeProvider: () => '心经',
      );

      final result = await service.postComment(
        'content-a',
        '这是一条评论',
        contentTitle: '功课标题',
      );

      expect(result['success'], false);
      expect(result['error'], '评论内容过长');
      expect(result['statusCode'], 422);
      expect(result['errorKey'], 'VALIDATION_ERROR');
      expect(capturedUseAuth, true);
      expect(capturedBody?['mainPractice'], '心经');
      expect(capturedBody?['videoTitle'], '功课标题');
    });

    test('postComment returns created comment model on success', () async {
      final service = CommentService.withDependencies(
        httpClient: FakeCommentHttpClient(
          postResponse: jsonResponse(
            '{"comment":{"id":1,"content_id":"content-a","user_id":"user-1","content":"随喜赞叹","created_at":"2026-05-04T00:00:00Z"}}',
            201,
          ),
        ),
      );

      final result = await service.postComment('content-a', '随喜赞叹');

      expect(result['success'], true);
      expect(result['comment'], isA<CommentModel>());
      expect((result['comment'] as CommentModel).videoId, 'content-a');
    });

    test('deleteComment returns true on successful deletion', () async {
      bool? capturedUseAuth;

      final service = CommentService.withDependencies(
        httpClient: FakeCommentHttpClient(
          deleteResponse: http.Response('', 200),
          onDelete: (url, useAuth) {
            capturedUseAuth = useAuth;
          },
        ),
      );

      final result = await service.deleteComment(42);

      expect(result, true);
      expect(capturedUseAuth, true);
    });
  });
}
