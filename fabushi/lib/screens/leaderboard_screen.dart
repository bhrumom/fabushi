import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_system/app_theme.dart';
import '../models/leaderboard_model.dart';
import '../widgets/follow_button.dart';
import '../widgets/leaderboard_user_detail_sheet.dart';
import '../widgets/space_background.dart';

String formatLeaderboardBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];

  double value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1000 && unitIndex < units.length - 1) {
    value /= 1000;
    unitIndex += 1;
  }

  var formatted = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  if (formatted.endsWith('.0')) {
    formatted = formatted.substring(0, formatted.length - 2);
  }

  return '$formatted ${units[unitIndex]}';
}

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
          title: const Text(
            '全球布施排行榜',
            style: TextStyle(color: Colors.white),
          ),
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
                      onPressed: () => model.fetchLeaderboard(forceRefresh: true),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            if (model.entries.isEmpty) {
              return const Center(
                child: Text(
                  '暂无排行榜数据',
                  style: TextStyle(color: Colors.white70),
                ),
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
                          onTap: () => LeaderboardUserDetailSheet.show(
                            context,
                            entry: entry,
                            highlightLabel: '累计布施',
                            highlightValue: formatLeaderboardBytes(entry.totalBytes),
                          ),
                          leading: _buildAvatarRank(entry),
                          title: Text(
                            entry.displayName.isNotEmpty
                                ? entry.displayName
                                : entry.username,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${entry.followerCount} 粉丝 · @${entry.username}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatLeaderboardBytes(entry.totalBytes),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(width: 10),
                              FollowButton(
                                username: entry.username,
                                initialIsFollowing: entry.isFollowing,
                                isSelf: entry.isSelf,
                                initialFollowerCount: null,
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

  Widget _buildAvatarRank(LeaderboardEntry entry) {
    final hasAvatar = entry.avatar?.isNotEmpty == true;
    final fallback = entry.displayName.isNotEmpty
        ? entry.displayName[0].toUpperCase()
        : (entry.username.isNotEmpty ? entry.username[0].toUpperCase() : '?');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: Colors.white10,
          backgroundImage: hasAvatar ? NetworkImage(entry.avatar!) : null,
          child: hasAvatar
              ? null
              : Text(
                  fallback,
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
              color: _rankColor(entry.rank),
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

  Color _rankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey;
    if (rank == 3) return Colors.brown;
    return const Color(0xFF476A8E);
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
