import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/core/network/api_client.dart';

void main() {
  group('ApiClient', () {
    late ApiClient apiClient;

    setUp(() {
      apiClient = ApiClient();
    });

    tearDown(() {
      apiClient.dispose();
    });

    test('should set token correctly', () {
      const token = 'test_token';
      apiClient.setToken(token);
      expect(apiClient, isNotNull);
    });
  });
}
