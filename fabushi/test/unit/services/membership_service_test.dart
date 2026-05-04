import 'package:flutter_test/flutter_test.dart';

import 'package:global_dharma_sharing/services/api_client.dart';
import 'package:global_dharma_sharing/services/membership_service.dart';

class FakeApiRequester implements ApiRequester {
  FakeApiRequester({this.getResponse, this.postResponse});

  final Map<String, dynamic>? getResponse;
  final Map<String, dynamic>? postResponse;

  @override
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    String? token,
  }) async {
    return getResponse ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    return postResponse ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  group('MembershipService', () {
    test('does not treat failed membership lookup as success', () async {
      final service = MembershipService(
        apiClient: FakeApiRequester(
          getResponse: {
            'success': false,
            'error': '登录已过期',
            'statusCode': 401,
            'errorKey': 'INVALID_TOKEN',
          },
        ),
      );

      final response = await service.getMembershipStatus('token');

      expect(response['success'], false);
      expect(response['message'], '登录已过期');
      expect(response['statusCode'], 401);
      expect(response['errorKey'], 'INVALID_TOKEN');
    });

    test('unwraps membership payload on success', () async {
      final service = MembershipService(
        apiClient: FakeApiRequester(
          getResponse: {
            'success': true,
            'membership': {'type': 'premium', 'isActive': true},
          },
        ),
      );

      final response = await service.getMembershipStatus('token');

      expect(response['success'], true);
      expect(response['membership']['type'], 'premium');
    });

    test('preserves backend failure message when creating payment session', () async {
      final service = MembershipService(
        apiClient: FakeApiRequester(
          postResponse: {
            'success': false,
            'error': '当前套餐不可购买',
            'statusCode': 422,
            'errorKey': 'VALIDATION_ERROR',
          },
        ),
      );

      final response = await service.createPaymentSession('token', 'yearly');

      expect(response['success'], false);
      expect(response['message'], '当前套餐不可购买');
      expect(response['statusCode'], 422);
      expect(response['errorKey'], 'VALIDATION_ERROR');
    });
  });
}
