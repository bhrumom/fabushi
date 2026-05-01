import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/auth_model.dart';
import 'package:global_dharma_sharing/services/membership_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MembershipService configuration', () {
    late MembershipService membershipService;

    setUp(() {
      membershipService = MembershipService();
    });

    test('exposes all paid membership plans', () {
      final prices = membershipService.getMembershipPrices();

      expect(prices.keys, containsAll(['monthly', 'quarterly', 'yearly']));
      for (final plan in prices.values) {
        expect(plan['name'], isA<String>());
        expect(plan['price'], isA<String>());
        expect(plan['duration'], isA<String>());
        expect(plan['features'], isA<List>());
      }
    });

    test('exposes trial membership details', () {
      final trialInfo = membershipService.getTrialMembership();

      expect(trialInfo['name'], isA<String>());
      expect(trialInfo['price'], '免费');
      expect(trialInfo['duration'], isA<String>());
      expect(trialInfo['features'], isA<List>());
    });
  });

  group('User model', () {
    test('round-trips JSON fields', () {
      final user = User.fromJson({
        'username': 'testuser',
        'email': 'test@example.com',
        'membershipType': 'paid',
        'membershipExpiry': '2024-12-31T23:59:59.000Z',
        'isAdmin': false,
      });

      final json = user.toJson();

      expect(json['username'], 'testuser');
      expect(json['email'], 'test@example.com');
      expect(json['membershipType'], 'paid');
      expect(json['isAdmin'], false);
      expect(json['membershipExpiry'], isNotNull);
    });

    test('detects active and expired memberships', () {
      final premiumUser = User(
        username: 'premium',
        email: 'premium@example.com',
        membershipType: 'paid',
        membershipExpiry: DateTime.now().add(const Duration(days: 30)),
      );
      final expiredUser = User(
        username: 'expired',
        email: 'expired@example.com',
        membershipType: 'paid',
        membershipExpiry: DateTime.now().subtract(const Duration(days: 1)),
      );
      final trialUser = User(
        username: 'trial',
        email: 'trial@example.com',
        membershipType: 'trial',
        membershipExpiry: DateTime.now().add(const Duration(days: 7)),
      );

      expect(premiumUser.hasPremiumMembership, true);
      expect(premiumUser.isPremiumMember, true);
      expect(expiredUser.hasPremiumMembership, false);
      expect(expiredUser.isPremiumMember, false);
      expect(trialUser.isTrialMember, true);
      expect(trialUser.hasPremiumMembership, true);
    });
  });
}
