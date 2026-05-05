import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/user_model.dart';
import 'package:global_dharma_sharing/services/auth_service.dart';

void main() {
  group('AuthService.buildLoginUser', () {
    test('tolerates partial user payloads from a successful login response', () {
      final user = AuthService.buildLoginUser(
        {
          'token': 'token-123',
          'username': 'android_fallback',
          'user': {
            'username': 'android_user',
            'nickname': '安卓用户',
            'phone_number': '+8613800000000',
            'membership': {
              'type': 'trial',
              'isActive': true,
            },
          },
        },
        requestedIdentifier: 'requested_name',
      );

      expect(user.username, 'android_user');
      expect(user.nickname, '安卓用户');
      expect(user.phoneNumber, '+8613800000000');
      expect(user.membership.type, 'trial');
      expect(user.membership.isActive, isTrue);
      expect(user.createdAt, isNotEmpty);
    });

    test('falls back to the requested identifier when login payload is minimal', () {
      final user = AuthService.buildLoginUser(
        {
          'token': 'token-456',
        },
        requestedIdentifier: 'fallback@example.com',
      );

      expect(user.username, 'fallback@example.com');
      expect(user.email, 'fallback@example.com');
      expect(user.membership, isA<MembershipInfo>());
      expect(user.membership.type, 'expired');
      expect(user.membership.isActive, isFalse);
    });
  });
}
