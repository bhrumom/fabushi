import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/leaderboard_model.dart';
import 'package:global_dharma_sharing/widgets/follow_button.dart';
import 'package:global_dharma_sharing/widgets/leaderboard_user_detail_sheet.dart';

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

  group('LeaderboardUserDetailSheet', () {
    testWidgets('renders summary and public records', (tester) async {
      final entry = LeaderboardEntry.fromJson({
        'username': 'alice',
        'displayName': 'Alice',
        'rank': 2,
        'totalBytes': 2048,
        'totalRecords': 3,
        'totalCount': 9,
        'totalDuration': 45,
        'totalDays': 2,
        'followerCount': 12,
        'followingCount': 4,
        'isFollowing': true,
        'privacy': {'isPrivate': false},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: LeaderboardUserDetailSheet(
              entry: entry,
              highlightLabel: '累计布施',
              highlightValue: '2.0 KB',
              recordsLoader: (_) async => [
                {
                  'sutra_name': '心经',
                  'record_date': '2026-05-06',
                  'local_time': '08:00',
                  'chant_count': 3,
                  'duration': 15,
                },
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('@alice'), findsOneWidget);
      expect(find.text('累计布施'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('12 粉丝 · 关注 4'), findsOneWidget);
      expect(find.text('公开修行记录'), findsOneWidget);
      expect(find.text('心经'), findsOneWidget);
      expect(find.text('2026-05-06 08:00 · 3 遍 · 15 分钟'), findsOneWidget);
    });

    testWidgets('shows empty state when no records are public', (tester) async {
      final entry = LeaderboardEntry.fromJson({
        'username': 'bob',
        'displayName': 'Bob',
        'rank': 1,
        'totalBytes': 0,
        'totalRecords': 0,
        'totalDays': 0,
        'followerCount': 0,
        'followingCount': 0,
        'privacy': {'isPrivate': true},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: LeaderboardUserDetailSheet(
              entry: entry,
              highlightLabel: '修行时长',
              highlightValue: '已私密',
              recordsLoader: (_) async => const [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('对方已将功课记录设为私密'), findsOneWidget);
      expect(find.text('暂无公开记录'), findsOneWidget);
    });
  });
}
