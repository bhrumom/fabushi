import 'package:flutter/material.dart';

import '../core/design_system/app_theme.dart';
import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';
import 'co_practice_group_panel.dart';
import 'follow_button.dart';
import 'leaderboard_user_detail_sheet.dart';

class PracticeLeaderboardSheet extends StatefulWidget {
  const PracticeLeaderboardSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PracticeLeaderboardSheet(),
    );
  }

  @override
  State<PracticeLeaderboardSheet> createState() =>
      _PracticeLeaderboardSheetState();
}

class _PracticeLeaderboardSheetState extends State<PracticeLeaderboardSheet> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LeaderboardEntry>> _load() async {
    final rows = await LeaderboardService().fetchPracticeLeaderboard(limit: 50);
    return rows.map((json) => LeaderboardEntry.fromJson(json)).toList();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.leaderboard, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '禅室修行榜单',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      tooltip: '刷新',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.white60,
                    tabs: const [Tab(text: '全球排行'), Tab(text: '小组排行')],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildGlobalLeaderboard(),
                      const CoPracticeGroupPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalLeaderboard() {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          );
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              '暂无修行排行数据',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _PracticeLeaderboardTile(
              entry: entry,
              onTap: () => LeaderboardUserDetailSheet.show(
                context,
                entry: entry,
                highlightLabel: '修行时长',
                highlightValue: _practiceMetric(entry),
              ),
              onFollowChanged: _refresh,
            );
          },
        );
      },
    );
  }

  String _practiceMetric(LeaderboardEntry entry) {
    if (entry.isPracticePrivate || entry.totalDuration == null) {
      return '已私密';
    }
    return _formatMinutes(entry.totalDuration!);
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 分钟';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return remain == 0 ? '$hours 小时' : '$hours 小时 $remain 分钟';
  }
}

class _PracticeLeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final VoidCallback onTap;
  final VoidCallback onFollowChanged;

  const _PracticeLeaderboardTile({
    required this.entry,
    required this.onTap,
    required this.onFollowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: AppTheme.glassDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName.isNotEmpty
                          ? entry.displayName
                          : entry.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.followerCount} 粉丝',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _durationText,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FollowButton(
                    username: entry.username,
                    initialIsFollowing: entry.isFollowing,
                    isSelf: entry.isSelf,
                    initialFollowerCount: null,
                    onChanged: onFollowChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _durationText {
    if (entry.isPracticePrivate || entry.totalDuration == null) return '已私密';
    return _formatMinutes(entry.totalDuration!);
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 分钟';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return remain == 0 ? '$hours 小时' : '$hours 小时 $remain 分钟';
  }

  String get _subtitle {
    if (entry.isPracticePrivate) return '功课记录已私密';
    final parts = <String>[
      if (entry.latestSutra?.isNotEmpty == true) entry.latestSutra!,
      if (entry.latestRecordDate?.isNotEmpty == true) entry.latestRecordDate!,
      '${entry.totalRecords} 条公开记录',
    ];
    return parts.join(' · ');
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: Colors.white10,
          backgroundImage:
              entry.avatar?.isNotEmpty == true ? NetworkImage(entry.avatar!) : null,
          child: entry.avatar?.isNotEmpty == true
              ? null
              : Text(
                  entry.rank.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        Positioned(
          right: -5,
          bottom: -5,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _rankColor,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF111111), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color get _rankColor {
    if (entry.rank == 1) return Colors.amber;
    if (entry.rank == 2) return Colors.grey;
    if (entry.rank == 3) return Colors.brown;
    return const Color(0xFF476A8E);
  }
}
