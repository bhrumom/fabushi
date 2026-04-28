import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';
import '../widgets/space_background.dart';
import '../core/design_system/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardModel>().fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('修行排行榜', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Consumer<LeaderboardModel>(
              builder: (context, model, _) {
                if (model.lastUpdateTime != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _formatUpdateTime(model.lastUpdateTime!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => context
                    .read<LeaderboardModel>()
                    .fetchLeaderboard(forceRefresh: true),
                tooltip: '刷新',
              ),
          ],
        ),
        body: Consumer<LeaderboardModel>(
          builder: (context, model, _) {
            if (model.isLoading && model.entries.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (model.error != null && model.entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(model.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          model.fetchLeaderboard(forceRefresh: true),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            if (model.entries.isEmpty) {
              return const Center(
                child: Text('暂无排行榜数据', style: TextStyle(color: Colors.white70)),
              );
            }

            return RefreshIndicator(
              onRefresh: () => model.fetchLeaderboard(forceRefresh: true),
              child: Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: model.entries.length,
                    itemBuilder: (context, index) {
                      final entry = model.entries[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: AppTheme.glassDecoration,
                        child: ListTile(
                          onTap: () => _showPracticeRecords(entry),
                          leading: _buildLeaderAvatar(entry),
                          title: Text(
                            entry.displayName.isNotEmpty
                                ? entry.displayName
                                : entry.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (entry.latestSutra?.isNotEmpty == true)
                                entry.latestSutra!,
                              if (entry.latestRecordDate?.isNotEmpty == true)
                                entry.latestRecordDate!,
                              '${entry.totalRecords} 条公开记录',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatPracticeCount(entry.totalCount),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.totalDays} 天',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (model.isLoading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(),
                    ),
                  if (model.error != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.red.shade100,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          model.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color;
    if (rank == 1) {
      color = Colors.amber;
    } else if (rank == 2) {
      color = Colors.grey;
    } else if (rank == 3) {
      color = Colors.brown;
    } else {
      color = Colors.blue;
    }

    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLeaderAvatar(LeaderboardEntry entry) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
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
          right: -4,
          bottom: -4,
          child: SizedBox(
            width: 22,
            height: 22,
            child: _buildRankBadge(entry.rank),
          ),
        ),
      ],
    );
  }

  void _showPracticeRecords(LeaderboardEntry entry) {
    showModalBottomSheet(
      context: context,
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
                        child: Center(child: CircularProgressIndicator()),
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
                      Flexible(
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
                            final count = record['chant_count'] ?? 0;
                            final duration = record['duration'] ?? 0;
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
                                '$date · ${_formatPracticeCount(_asInt(count))} · ${_formatMinutes(_asInt(duration))}',
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

  String _formatPracticeCount(int count) {
    return '$count 遍';
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 分钟';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return remain == 0 ? '$hours 小时' : '$hours 小时 $remain 分钟';
  }

  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚更新';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
