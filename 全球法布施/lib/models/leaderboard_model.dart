import 'package:flutter/foundation.dart';
import '../services/leaderboard_service.dart';

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
  final LeaderboardService _service = LeaderboardService();
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  
  List<LeaderboardEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await _service.fetchLeaderboard();
      _entries = data.map((json) => LeaderboardEntry.fromJson(json)).toList();
    } catch (e) {
      _error = '获取排行榜失败: $e';
      _entries = [];
    }
    
    _isLoading = false;
    notifyListeners();
  }
}
