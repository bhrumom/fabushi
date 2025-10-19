import 'package:flutter/material.dart';
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
    Future.microtask(() => context.read<LeaderboardModel>().fetchLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全球排行榜')),
      body: Consumer<LeaderboardModel>(
        builder: (context, model, _) {
          if (model.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
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
}
