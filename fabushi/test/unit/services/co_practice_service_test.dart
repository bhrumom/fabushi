import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:global_dharma_sharing/services/co_practice_service.dart';

void main() {
  CoPracticeService createService(MockClient client) {
    return CoPracticeService(
      httpClient: client,
      baseUrlResolver: () async => 'https://example.com',
      headersResolver: () async => const {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer test-token',
      },
    );
  }

  test('searchGroupsWithStatus returns groups on success', () async {
    final service = createService(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/meditation/groups');
        expect(request.url.queryParameters['query'], '晨课');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          '{"success":true,"data":{"groups":[{"id":21,"name":"晨课共修","description":"每天一起完成早课","ownerUsername":"owner1","ownerName":"发起人","requireApproval":true,"dailyGoalMinutes":30,"cumulativeMissLimit":7,"consecutiveMissLimit":3,"memberCount":5,"pendingCount":2,"totalDuration":180,"todayDuration":45}]}}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.searchGroupsWithStatus(query: '晨课');

    expect(result.hasError, isFalse);
    expect(result.statusCode, isNull);
    expect(result.groups, hasLength(1));
    expect(result.groups.single.name, '晨课共修');
    expect(result.groups.single.ownerName, '发起人');
    expect(result.groups.single.publicCode, '000021');
  });

  test('searchGroupsWithStatus surfaces backend error messages', () async {
    final service = createService(
      MockClient(
        (_) async => http.Response(
          '{"success":false,"error":"meditation_groups 表尚未完成迁移"}',
          500,
          headers: const {'content-type': 'application/json'},
        ),
      ),
    );

    final result = await service.searchGroupsWithStatus(query: '晨课');

    expect(result.hasError, isTrue);
    expect(result.groups, isEmpty);
    expect(result.statusCode, 500);
    expect(result.errorMessage, 'meditation_groups 表尚未完成迁移');
  });

  test('createGroup returns group id on success', () async {
    final service = createService(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/meditation/groups');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          '{"success":true,"data":{"groupId":42}}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.createGroup(
      name: '晨课共修',
      description: '每天一起完成早课',
      requireApproval: true,
      dailyGoalMinutes: 30,
      cumulativeMissLimit: 7,
      consecutiveMissLimit: 3,
    );

    expect(result.isSuccess, isTrue);
    expect(result.groupId, 42);
    expect(result.errorMessage, isNull);
  });

  test('createGroup surfaces backend error messages', () async {
    final service = createService(
      MockClient(
        (_) async => http.Response(
          '{"success":false,"error":"meditation_groups 表尚未完成迁移"}',
          500,
          headers: const {'content-type': 'application/json'},
        ),
      ),
    );

    final result = await service.createGroup(
      name: '晨课共修',
      requireApproval: true,
      dailyGoalMinutes: 30,
      cumulativeMissLimit: 7,
      consecutiveMissLimit: 3,
    );

    expect(result.isSuccess, isFalse);
    expect(result.groupId, isNull);
    expect(result.statusCode, 500);
    expect(result.errorMessage, 'meditation_groups 表尚未完成迁移');
  });

  test('createGroup falls back when response body has no message', () async {
    final service = createService(
      MockClient(
        (_) async => http.Response(
          '{"success":false}',
          400,
          headers: const {'content-type': 'application/json'},
        ),
      ),
    );

    final result = await service.createGroup(
      name: '晨课共修',
      requireApproval: true,
      dailyGoalMinutes: 30,
      cumulativeMissLimit: 7,
      consecutiveMissLimit: 3,
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, '创建共修小组失败');
    expect(result.statusCode, 400);
  });
}
