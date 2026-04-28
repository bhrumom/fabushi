import 'package:flutter/material.dart';

import '../core/design_system/app_theme.dart';
import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';

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
    return SafeArea(
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
                      '禅室修行排行榜',
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
              Expanded(
                child: FutureBuilder<List<LeaderboardEntry>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFD4AF37),
                        ),
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
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _PracticeLeaderboardTile(
                          entry: entry,
                          onTap: () => _showRecords(context, entry),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecords(BuildContext context, LeaderboardEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: LeaderboardService().fetchPublicPracticeRecords(
            entry.username,
          ),
          builder: (context, snapshot) {
            final records = snapshot.data ?? [];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${entry.displayName} 的公开修行记录',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            '暂无公开记录',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.48,
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
                            final date =
                                record['record_date']?.toString() ?? '';
                            final count = _asInt(record['chant_count']);
                            final duration = _asInt(record['duration']);
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
                                '$date · ${_formatPracticeCount(count)} · ${_formatMinutes(duration)}',
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatPracticeCount(int count) => '$count 遍';

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

  const _PracticeLeaderboardTile({required this.entry, required this.onTap});

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
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.totalCount} 遍',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.totalDays} 天',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _subtitle {
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
          backgroundImage: entry.avatar?.isNotEmpty == true
              ? NetworkImage(entry.avatar!)
              : null,
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
