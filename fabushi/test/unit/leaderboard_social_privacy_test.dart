import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/leaderboard_model.dart';
import 'package:global_dharma_sharing/widgets/follow_button.dart';

void main() {
  group('LeaderboardEntry social and privacy parsing', () {
    test('parses social fields from API response', () {
      final entry = LeaderboardEntry.fromJson({
        'username': 'alice',
        'displayName': 'Alice',
        'rank': 3,
        'totalBytes': '2048',
        'totalRecords': 8,
        'totalCount': '108',
        'totalDuration': 3600,
        'totalDays': 4,
        'follower_count': '12',
        'followingCount': 5,
        'is_following': 1,
        'isSelf': false,
        'privacy': {
          'isPrivate': false,
          'showPracticeName': true,
          'showDuration': true,
          'showChantCount': false,
        },
      });

      expect(entry.username, 'alice');
      expect(entry.displayName, 'Alice');
      expect(entry.followerCount, 12);
      expect(entry.followingCount, 5);
      expect(entry.isFollowing, isTrue);
      expect(entry.isSelf, isFalse);
      expect(entry.canShowPracticeName, isTrue);
      expect(entry.canShowDuration, isTrue);
      expect(entry.canShowChantCount, isFalse);
    });

    test('private practice hides all public practice detail getters', () {
      final entry = LeaderboardEntry.fromJson({
        'username': 'bob',
        'rank': 1,
        'totalBytes': 0,
        'totalRecords': 0,
        'totalDays': 0,
        'privacy': {
          'is_private': 1,
          'show_practice_name': 1,
          'show_duration': 1,
          'show_chant_count': 1,
        },
      });

      expect(entry.isPracticePrivate, isTrue);
      expect(entry.canShowPracticeName, isFalse);
      expect(entry.canShowDuration, isFalse);
      expect(entry.canShowChantCount, isFalse);
    });
  });

  group('FollowButton', () {
    testWidgets('renders self state without a follow action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FollowButton(username: 'me', isSelf: true),
          ),
        ),
      );

      expect(find.text('自己'), findsOneWidget);
      expect(find.text('关注'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders following state and follower count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFF121212),
            body: FollowButton(
              username: 'alice',
              initialIsFollowing: true,
              initialFollowerCount: 9,
            ),
          ),
        ),
      );

      expect(find.text('已关注'), findsOneWidget);
      expect(find.text('9 粉丝'), findsOneWidget);
    });
  });
}
