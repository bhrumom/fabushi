import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/user_model.dart';
import 'package:global_dharma_sharing/services/auth_service.dart';

void main() {
  group('AuthService.buildLoginUser', () {
    test(
      'tolerates partial user payloads from a successful login response',
      () {
        final user = AuthService.buildLoginUser({
          'token': 'token-123',
          'username': 'android_fallback',
          'user': {
            'username': 'android_user',
            'nickname': '安卓用户',
            'phone_number': '+8613800000000',
            'membership': {'type': 'trial', 'isActive': true},
          },
        }, requestedIdentifier: 'requested_name');

        expect(user.username, 'android_user');
        expect(user.nickname, '安卓用户');
        expect(user.phoneNumber, '+8613800000000');
        expect(user.membership.type, 'trial');
        expect(user.membership.isActive, isTrue);
        expect(user.createdAt, isNotEmpty);
      },
    );

    test('preserves user number from successful login response', () {
      final user = AuthService.buildLoginUser({
        'token': 'token-789',
        'user': {
          'username': 'student_user',
          'userNo': 618273941,
          'email': 'student@example.com',
        },
      }, requestedIdentifier: 'student_user');

      expect(user.username, 'student_user');
      expect(user.userNo, 618273941);
      expect(user.email, 'student@example.com');
    });

    test(
      'falls back to the requested identifier when login payload is minimal',
      () {
        final user = AuthService.buildLoginUser({
          'token': 'token-456',
        }, requestedIdentifier: 'fallback@example.com');

        expect(user.username, 'fallback@example.com');
        expect(user.email, 'fallback@example.com');
        expect(user.membership, isA<MembershipInfo>());
        expect(user.membership.type, 'expired');
        expect(user.membership.isActive, isFalse);
      },
    );
  });

  group('AuthService.buildRefreshedUser', () {
    test('parses user-info payload with user number and nested membership', () {
      final user = AuthService.buildRefreshedUser({
        'username': 'profile_user',
        'userNo': 987654321,
        'email': 'profile@example.com',
        'emailVerified': true,
        'nickname': '资料用户',
        'avatar': 'https://example.com/avatar.png',
        'phoneNumber': '+8613800000000',
        'firebaseUid': 'firebase-uid',
        'alipayUserId': 'alipay-uid',
        'membership': {'type': 'paid', 'expiresAt': '2099-01-01T00:00:00.000Z'},
      });

      expect(user.username, 'profile_user');
      expect(user.userNo, 987654321);
      expect(user.nickname, '资料用户');
      expect(user.avatar, 'https://example.com/avatar.png');
      expect(user.phoneNumber, '+8613800000000');
      expect(user.firebaseUid, 'firebase-uid');
      expect(user.alipayUserId, 'alipay-uid');
      expect(user.membership.type, 'paid');
      expect(user.membership.expiresAt, '2099-01-01T00:00:00.000Z');
      expect(user.membership.isActive, isTrue);
    });

    test('keeps fallback user number when refresh payload omits it', () {
      final fallbackUser = UserModel(
        username: 'existing_user',
        userNo: 123456789,
        email: 'old@example.com',
        emailVerified: true,
        createdAt: '2026-05-01T00:00:00.000Z',
        membership: MembershipInfo(
          type: 'trial',
          isActive: true,
          expiresAt: '2099-01-01T00:00:00.000Z',
        ),
      );

      final user = AuthService.buildRefreshedUser({
        'username': 'existing_user',
        'email': 'new@example.com',
        'membership': {'type': 'paid', 'expiresAt': '2099-02-01T00:00:00.000Z'},
      }, fallbackUser: fallbackUser);

      expect(user.userNo, 123456789);
      expect(user.email, 'new@example.com');
      expect(user.membership.type, 'paid');
      expect(user.membership.expiresAt, '2099-02-01T00:00:00.000Z');
    });
  });
}
