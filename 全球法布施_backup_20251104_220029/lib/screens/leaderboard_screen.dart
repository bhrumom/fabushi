import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/leaderboard_model.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('全球排行榜'),
        actions: [
          Consumer<LeaderboardModel>(
            builder: (context, model, _) {
              if (model.lastUpdateTime != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _formatUpdateTime(model.lastUpdateTime!),
                      style: const TextStyle(fontSize: 12),
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
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<LeaderboardModel>().fetchLeaderboard(forceRefresh: true),
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
            return const Center(child: Text('暂无排行榜数据'));
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
                    return Card(
                      child: ListTile(
                        leading: _buildRankBadge(entry.rank),
                        title: Text(entry.username),
                        trailing: Text(_formatBytes(entry.totalBytes)),
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
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color;
    if (rank == 1) color = Colors.amber;
    else if (rank == 2) color = Colors.grey;
    else if (rank == 3) color = Colors.brown;
    else color = Colors.blue;

    return CircleAvatar(
      backgroundColor: color,
      child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
