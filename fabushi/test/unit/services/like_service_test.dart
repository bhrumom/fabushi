import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:global_dharma_sharing/models/liked_item.dart';
import 'package:global_dharma_sharing/services/like_service.dart';

http.Response jsonResponse(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class FakeLikeHttpClient implements LikeHttpClient {
  FakeLikeHttpClient({this.onGet, this.onPost});

  final Future<http.Response> Function(Uri url, Map<String, String>? headers)? onGet;
  final Future<http.Response> Function(
    Uri url,
    Map<String, String>? headers,
    Object? body,
  )? onPost;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return onGet?.call(url, headers) ?? http.Response('', 500);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return onPost?.call(url, headers, body) ?? http.Response('', 500);
  }
}

class MemoryLikeStorage implements LikeStorage {
  MemoryLikeStorage([Map<String, String>? seed]) : _values = {...?seed};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

LikedItem buildLikedItem({
  required String id,
  required DateTime likedAt,
  String? filePath,
}) {
  return LikedItem(
    id: id,
    username: '文章标题',
    description: '随喜赞叹',
    profileImageUrl: '',
    likedAt: likedAt,
    contentType: 'text',
    filePath: filePath,
  );
}

void main() {
  group('LikeService', () {
    test('initialize loads cached likes and merges cloud likes', () async {
      final storage = MemoryLikeStorage({
        'liked_items_user-1':
            '[{"id":"local-1","username":"本地标题","description":"本地","profileImageUrl":"","likedAt":"2026-05-04T00:00:00Z","contentType":"text"}]',
      });

      final service = LikeService.withDependencies(
        storage: storage,
        httpClient: FakeLikeHttpClient(
          onGet: (url, headers) async {
            expect(headers?['Authorization'], 'Bearer token');
            return jsonResponse(
              '{"success":true,"likes":[{"id":"cloud-1","title":"云端标题","description":"云端","profileImageUrl":"","likedAt":"2026-05-04T01:00:00Z","contentType":"text"}]}',
              200,
            );
          },
        ),
      );

      service.setAuthToken('token');
      await service.initialize(userId: 'user-1');

      expect(service.isInitialized, true);
      expect(service.likedCount, 2);
      expect(service.isLiked('local-1'), true);
      expect(service.isLiked('cloud-1'), true);
    });

    test('initialize ignores malformed cached payloads', () async {
      final service = LikeService.withDependencies(
        storage: MemoryLikeStorage({'liked_items_user-1': 'not-json'}),
        httpClient: FakeLikeHttpClient(),
      );

      await service.initialize(userId: 'user-1');

      expect(service.isInitialized, true);
      expect(service.likedCount, 0);
    });

    test('toggleLike sends title and file path and applies returned count', () async {
      Map<String, dynamic>? capturedBody;
      Map<String, String>? capturedHeaders;

      final service = LikeService.withDependencies(
        storage: MemoryLikeStorage(),
        httpClient: FakeLikeHttpClient(
          onPost: (url, headers, body) async {
            capturedHeaders = headers;
            capturedBody = Map<String, dynamic>.from(
              jsonDecode(body! as String) as Map,
            );
            return jsonResponse('{"likeCount":9}', 200);
          },
        ),
      );

      service.setAuthToken('token');
      final item = buildLikedItem(
        id: 'content-a',
        likedAt: DateTime.parse('2026-05-04T02:00:00Z'),
        filePath: '/notes/a.md',
      );

      await service.toggleLike(item);
      await Future<void>.delayed(Duration.zero);

      expect(service.isLiked('content-a'), true);
      expect(service.getLikeCount('content-a'), 9);
      expect(capturedHeaders?['Authorization'], 'Bearer token');
      expect(capturedBody?['title'], '文章标题');
      expect(capturedBody?['filePath'], '/notes/a.md');
      expect(capturedBody?['action'], 'like');
    });

    test('fetchLikeCounts updates numeric counts only', () async {
      final service = LikeService.withDependencies(
        storage: MemoryLikeStorage(),
        httpClient: FakeLikeHttpClient(
          onPost: (url, headers, body) async {
            return jsonResponse(
              '{"likeCounts":{"content-a":4,"content-b":0,"ignored":"oops"}}',
              200,
            );
          },
        ),
      );

      await service.fetchLikeCounts(['content-a', 'content-b', 'ignored']);

      expect(service.getLikeCount('content-a'), 4);
      expect(service.getLikeCount('content-b'), 0);
      expect(service.getLikeCount('ignored'), 0);
    });

    test('fetchReceivedLikeCount ignores malformed payloads', () async {
      final service = LikeService.withDependencies(
        storage: MemoryLikeStorage(),
        httpClient: FakeLikeHttpClient(
          onGet: (url, headers) async {
            return http.Response('upstream unavailable', 503);
          },
        ),
      );

      service.setAuthToken('token');
      await service.fetchReceivedLikeCount();

      expect(service.receivedLikeCount, 0);
    });
  });
}
