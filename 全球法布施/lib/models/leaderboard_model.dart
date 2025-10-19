import 'package:flutter/foundation.dart';

class LeaderboardEntry {
  final String username;
  final int totalBytes;
  final int rank;
  
  LeaderboardEntry({
    required this.username,
    required this.totalBytes,
    required this.rank,
  });
  
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      username: json['username'] ?? '',
      totalBytes: json['totalBytes'] ?? 0,
      rank: json['rank'] ?? 0,
    );
  }
}

class LeaderboardModel extends ChangeNotifier {
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;
  
  List<LeaderboardEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  
  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    notifyListeners();
    
    // TODO: 从API获取排行榜数据
    await Future.delayed(const Duration(seconds: 1));
    
    _entries = List.generate(10, (i) => LeaderboardEntry(
      username: '用户${i + 1}',
      totalBytes: (10 - i) * 1024 * 1024 * 100,
      rank: i + 1,
    ));
    
    _isLoading = false;
    notifyListeners();
  }
}
