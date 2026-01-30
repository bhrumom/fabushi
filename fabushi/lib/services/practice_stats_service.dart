import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_settings.dart';

/// 修行统计数据模型
class PracticeStats {
  final TodayStats today;
  final TotalStats total;
  final int consecutiveDays;
  final List<SubjectStats> bySubject;

  PracticeStats({
    required this.today,
    required this.total,
    required this.consecutiveDays,
    required this.bySubject,
  });

  factory PracticeStats.empty() => PracticeStats(
    today: TodayStats.empty(),
    total: TotalStats.empty(),
    consecutiveDays: 0,
    bySubject: [],
  );

  factory PracticeStats.fromJson(Map<String, dynamic> json) {
    return PracticeStats(
      today: TodayStats.fromJson(json['today'] ?? {}),
      total: TotalStats.fromJson(json['total'] ?? {}),
      consecutiveDays: json['consecutiveDays'] ?? 0,
      bySubject: (json['bySubject'] as List<dynamic>?)
          ?.map((e) => SubjectStats.fromJson(e))
          .toList() ?? [],
    );
  }
}

class TodayStats {
  final String? sutra;
  final int count;
  final int duration;

  TodayStats({this.sutra, required this.count, required this.duration});

  factory TodayStats.empty() => TodayStats(count: 0, duration: 0);

  factory TodayStats.fromJson(Map<String, dynamic> json) {
    return TodayStats(
      sutra: json['sutra'],
      count: json['count'] ?? 0,
      duration: json['duration'] ?? 0,
    );
  }
}

class TotalStats {
  final int records;
  final int count;
  final int duration;
  final int days;

  TotalStats({required this.records, required this.count, required this.duration, required this.days});

  factory TotalStats.empty() => TotalStats(records: 0, count: 0, duration: 0, days: 0);

  factory TotalStats.fromJson(Map<String, dynamic> json) {
    return TotalStats(
      records: json['records'] ?? 0,
      count: json['count'] ?? 0,
      duration: json['duration'] ?? 0,
      days: json['days'] ?? 0,
    );
  }
}

class SubjectStats {
  final String sutraName;
  final int count;
  final int duration;
  final int days;

  SubjectStats({required this.sutraName, required this.count, required this.duration, required this.days});

  factory SubjectStats.fromJson(Map<String, dynamic> json) {
    return SubjectStats(
      sutraName: json['sutra_name'] ?? '',
      count: json['count'] ?? 0,
      duration: json['duration'] ?? 0,
      days: json['days'] ?? 0,
    );
  }
}

/// 日统计数据
class DayStats {
  final String date;
  final String day;
  final int count;
  final int duration;

  DayStats({required this.date, required this.day, required this.count, required this.duration});

  factory DayStats.fromJson(Map<String, dynamic> json) {
    return DayStats(
      date: json['date'] ?? '',
      day: json['day'] ?? '',
      count: json['count'] ?? 0,
      duration: json['duration'] ?? 0,
    );
  }
}

/// 发愿目标
class PracticeGoal {
  final int id;
  final String sutraName;
  final int targetCount;
  final int currentCount;
  final String? dedication;
  final String status;
  final int progress;

  PracticeGoal({
    required this.id,
    required this.sutraName,
    required this.targetCount,
    required this.currentCount,
    this.dedication,
    required this.status,
    required this.progress,
  });

  factory PracticeGoal.fromJson(Map<String, dynamic> json) {
    return PracticeGoal(
      id: json['id'] ?? 0,
      sutraName: json['sutra_name'] ?? '',
      targetCount: json['target_count'] ?? 0,
      currentCount: json['current_count'] ?? 0,
      dedication: json['dedication'],
      status: json['status'] ?? 'active',
      progress: json['progress'] ?? 0,
    );
  }
}

/// 修行记录服务
class PracticeStatsService extends ChangeNotifier {
  static final PracticeStatsService _instance = PracticeStatsService._internal();
  factory PracticeStatsService() => _instance;
  PracticeStatsService._internal();

  String? _authToken;
  PracticeStats _stats = PracticeStats.empty();
  List<DayStats> _weeklyData = [];
  List<DayStats> _monthlyData = [];
  List<PracticeGoal> _goals = [];
  int _weekTotal = 0;
  int _monthTotal = 0;
  bool _isLoading = false;

  // Getters
  PracticeStats get stats => _stats;
  List<DayStats> get weeklyData => _weeklyData;
  List<DayStats> get monthlyData => _monthlyData;
  List<PracticeGoal> get goals => _goals;
  int get weekTotal => _weekTotal;
  int get monthTotal => _monthTotal;
  bool get isLoading => _isLoading;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<String> get _baseUrl async => await AppSettings.getBackendUrl();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_authToken',
    'Content-Type': 'application/json',
  };

  /// 获取修行统计概览
  Future<bool> fetchStats() async {
    if (_authToken == null) return false;
    
    _isLoading = true;
    notifyListeners();

    try {
      final url = await _baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/meditation/stats'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _stats = PracticeStats.fromJson(data['data']);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('获取修行统计失败: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 获取周统计数据
  Future<bool> fetchWeeklyStats() async {
    if (_authToken == null) return false;

    try {
      final url = await _baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/meditation/weekly'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _weeklyData = (data['data']['days'] as List<dynamic>?)
              ?.map((e) => DayStats.fromJson(e))
              .toList() ?? [];
          _weekTotal = data['data']['weekTotal'] ?? 0;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('获取周统计失败: $e');
    }
    return false;
  }

  /// 获取月统计数据
  Future<bool> fetchMonthlyStats() async {
    if (_authToken == null) return false;

    try {
      final url = await _baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/meditation/monthly'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _monthlyData = (data['data']['days'] as List<dynamic>?)
              ?.map((e) => DayStats.fromJson(e))
              .toList() ?? [];
          _monthTotal = data['data']['monthTotal'] ?? 0;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('获取月统计失败: $e');
    }
    return false;
  }

  /// 获取发愿目标
  Future<bool> fetchGoals() async {
    if (_authToken == null) return false;

    try {
      final url = await _baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/meditation/goal'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _goals = (data['data']['goals'] as List<dynamic>?)
              ?.map((e) => PracticeGoal.fromJson(e))
              .toList() ?? [];
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('获取发愿目标失败: $e');
    }
    return false;
  }

  /// 设置发愿目标
  Future<bool> setGoal({
    required String sutra,
    required int targetCount,
    String? dedication,
  }) async {
    if (_authToken == null) return false;

    try {
      final url = await _baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/meditation/goal'),
        headers: _headers,
        body: jsonEncode({
          'sutra': sutra,
          'targetCount': targetCount,
          'dedication': dedication ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await fetchGoals();
          return true;
        }
      }
    } catch (e) {
      debugPrint('设置发愿目标失败: $e');
    }
    return false;
  }

  /// 补录功课
  Future<bool> addManualRecord({
    required String sutra,
    required int chantCount,
    int duration = 0,
    String? recordDate,
    String? notes,
  }) async {
    if (_authToken == null) return false;

    try {
      final url = await _baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/meditation/record'),
        headers: _headers,
        body: jsonEncode({
          'sutra': sutra,
          'sutraSource': 'custom',
          'chantCount': chantCount,
          'duration': duration,
          'isManual': true,
          'recordDate': recordDate,
          'notes': notes ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // 刷新统计数据
          await fetchStats();
          await fetchWeeklyStats();
          return true;
        }
      }
    } catch (e) {
      debugPrint('补录功课失败: $e');
    }
    return false;
  }

  /// 同步修行记录（实时）
  Future<bool> syncRecord({
    required String sutra,
    String sutraSource = 'asset',
    required int chantCount,
    required int duration,
  }) async {
    if (_authToken == null) return false;

    try {
      final url = await _baseUrl;
      final response = await http.post(
        Uri.parse('$url/api/meditation/record'),
        headers: _headers,
        body: jsonEncode({
          'sutra': sutra,
          'sutraSource': sutraSource,
          'chantCount': chantCount,
          'duration': duration,
          'isManual': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // 刷新统计数据
          await fetchStats();
          return true;
        }
      }
    } catch (e) {
      debugPrint('同步修行记录失败: $e');
    }
    return false;
  }

  /// 加载所有数据
  Future<void> loadAllData() async {
    await fetchStats();
    await fetchWeeklyStats();
    await fetchGoals();
  }
}
