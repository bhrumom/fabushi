import 'package:flutter/material.dart';

import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';
import 'follow_button.dart';

typedef PublicPracticeRecordLoader =
    Future<List<Map<String, dynamic>>> Function(String username);

class LeaderboardUserDetailSheet extends StatelessWidget {
  final LeaderboardEntry entry;
  final String highlightLabel;
  final String highlightValue;
  final PublicPracticeRecordLoader? recordsLoader;

  const LeaderboardUserDetailSheet({
    super.key,
    required this.entry,
    required this.highlightLabel,
    required this.highlightValue,
    this.recordsLoader,
  });

  static Future<void> show(
    BuildContext context, {
    required LeaderboardEntry entry,
    required String highlightLabel,
    required String highlightValue,
    PublicPracticeRecordLoader? recordsLoader,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => LeaderboardUserDetailSheet(
        entry: entry,
        highlightLabel: highlightLabel,
        highlightValue: highlightValue,
        recordsLoader: recordsLoader,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadRecords() {
    final loader = recordsLoader;
    if (loader != null) {
      return loader(entry.username);
    }
    return LeaderboardService().fetchPublicPracticeRecords(entry.username);
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        entry.displayName.isNotEmpty ? entry.displayName : entry.username;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadRecords(),
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <Map<String, dynamic>>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(displayName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${entry.username}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${entry.followerCount} 粉丝 · 关注 ${entry.followingCount}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FollowButton(
                      username: entry.username,
                      initialIsFollowing: entry.isFollowing,
                      isSelf: entry.isSelf,
                      initialFollowerCount: entry.followerCount,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        highlightLabel,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          highlightValue,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.isPracticePrivate) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '对方已将功课记录设为私密',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  '公开修行记录',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  )
                else if (records.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '暂无公开记录',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: records.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final sutra =
                            record['sutra_name']?.toString() ?? '修行功课';
                        final date = record['record_date']?.toString() ?? '';
                        final localTime =
                            record['local_time']?.toString() ?? '';
                        final count = record['chant_count'] == null
                            ? null
                            : _asInt(record['chant_count']);
                        final duration = record['duration'] == null
                            ? null
                            : _asInt(record['duration']);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.self_improvement,
                            color: Color(0xFFD4AF37),
                          ),
                          title: Text(
                            sutra,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            [
                              _formatDateTime(date, localTime),
                              if (count != null) _formatPracticeCount(count),
                              if (duration != null) _formatMinutes(duration),
                            ].where((part) => part.isNotEmpty).join(' · '),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(String displayName) {
    final initial = displayName.isNotEmpty ? displayName[0] : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white10,
      backgroundImage:
          entry.avatar?.isNotEmpty == true ? NetworkImage(entry.avatar!) : null,
      child: entry.avatar?.isNotEmpty == true
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatPracticeCount(int count) => '$count 遍';

  String _formatDateTime(String date, String localTime) {
    if (date.isEmpty) return localTime;
    if (localTime.isEmpty) return date;
    return '$date $localTime';
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 分钟';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return remain == 0 ? '$hours 小时' : '$hours 小时 $remain 分钟';
  }
}
