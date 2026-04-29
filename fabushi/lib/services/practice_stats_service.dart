import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import 'app_settings.dart';

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
  }
  return 0;
}

String _asString(dynamic value) => value?.toString() ?? '';

String? _emptyToNull(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

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
    final subjects = json['bySubject'] as List<dynamic>?;
    return PracticeStats(
      today: TodayStats.fromJson(
        Map<String, dynamic>.from(json['today'] ?? {}),
      ),
      total: TotalStats.fromJson(
        Map<String, dynamic>.from(json['total'] ?? {}),
      ),
      consecutiveDays: _asInt(json['consecutiveDays']),
      bySubject:
          subjects
              ?.map(
                (e) =>
                    SubjectStats.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          [],
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
      sutra: json['sutra']?.toString(),
      count: _asInt(json['count']),
      duration: _asInt(json['duration']),
    );
  }
}

class TotalStats {
  final int records;
  final int count;
  final int duration;
  final int days;

  TotalStats({
    required this.records,
    required this.count,
    required this.duration,
    required this.days,
  });

  factory TotalStats.empty() =>
      TotalStats(records: 0, count: 0, duration: 0, days: 0);

  factory TotalStats.fromJson(Map<String, dynamic> json) {
    return TotalStats(
      records: _asInt(json['records']),
      count: _asInt(json['count']),
      duration: _asInt(json['duration']),
      days: _asInt(json['days']),
    );
  }
}

class SubjectStats {
  final String sutraName;
  final int count;
  final int duration;
  final int days;

  SubjectStats({
    required this.sutraName,
    required this.count,
    required this.duration,
    required this.days,
  });

  factory SubjectStats.fromJson(Map<String, dynamic> json) {
    return SubjectStats(
      sutraName: _asString(json['sutra_name'] ?? json['sutraName']),
      count: _asInt(json['count']),
      duration: _asInt(json['duration']),
      days: _asInt(json['days']),
    );
  }
}

/// 日统计数据
class DayStats {
  final String date;
  final String day;
  final int count;
  final int duration;

  DayStats({
    required this.date,
    required this.day,
    required this.count,
    required this.duration,
  });

  factory DayStats.fromJson(Map<String, dynamic> json) {
    final date = _asString(json['date'] ?? json['record_date']);
    return DayStats(
      date: date,
      day: _asString(json['day']),
      count: _asInt(json['count']),
      duration: _asInt(json['duration']),
    );
  }
}

/// 单条云端修行记录
class PracticeRecord {
  final int id;
  final String sutraName;
  final String sutraSource;
  final int duration;
  final int chantCount;
  final String recordDate;
  final String? localTime;
  final int? timezoneOffsetMinutes;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isManual;
  final String? notes;
  final DateTime? createdAt;

  PracticeRecord({
    required this.id,
    required this.sutraName,
    required this.sutraSource,
    required this.duration,
    required this.chantCount,
    required this.recordDate,
    this.localTime,
    this.timezoneOffsetMinutes,
    this.startTime,
    this.endTime,
    required this.isManual,
    this.notes,
    this.createdAt,
  });

  factory PracticeRecord.fromJson(Map<String, dynamic> json) {
    final notes = json['notes']?.toString();
    return PracticeRecord(
      id: _asInt(json['id']),
      sutraName: _asString(
        json['sutra_name'] ?? json['sutraName'] ?? json['sutra'],
      ),
      sutraSource: _asString(
        json['sutra_source'] ?? json['sutraSource'] ?? 'custom',
      ),
      duration: _asInt(json['duration']),
      chantCount: _asInt(json['chant_count'] ?? json['chantCount']),
      recordDate: _asString(json['record_date'] ?? json['recordDate']),
      localTime: _emptyToNull(json['local_time'] ?? json['localTime']),
      timezoneOffsetMinutes: _nullableInt(
        json['timezone_offset_minutes'] ?? json['timezoneOffsetMinutes'],
      ),
      startTime: DateTime.tryParse(
        _asString(json['start_time'] ?? json['startTime']),
      ),
      endTime: DateTime.tryParse(
        _asString(json['end_time'] ?? json['endTime']),
      ),
      isManual:
          json['is_manual'] == true ||
          json['is_manual'] == 1 ||
          json['isManual'] == true,
      notes: notes == null || notes.isEmpty ? null : notes,
      createdAt: DateTime.tryParse(
        _asString(json['created_at'] ?? json['createdAt']),
      ),
    );
  }

  String get sourceLabel => isManual ? '补录' : '禅室';
  String get dateTimeLabel =>
      localTime?.isNotEmpty == true ? '$recordDate $localTime' : recordDate;
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
      id: _asInt(json['id']),
      sutraName: _asString(json['sutra_name'] ?? json['sutraName']),
      targetCount: _asInt(json['target_count'] ?? json['targetCount']),
      currentCount: _asInt(json['current_count'] ?? json['currentCount']),
      dedication: json['dedication']?.toString(),
      status: _asString(json['status']).isEmpty
          ? 'active'
          : _asString(json['status']),
      progress: _asInt(json['progress']),
    );
  }
}

/// 修行记录服务。云端为主存储；网络异常时保留待同步队列，恢复后自动补传。
class PracticeStatsService extends ChangeNotifier {
  static final PracticeStatsService _instance =
      PracticeStatsService._internal();
  factory PracticeStatsService() => _instance;
  PracticeStatsService._internal();

  String? _authToken;
  String? _authUsername;
  PracticeStats _stats = PracticeStats.empty();
  List<DayStats> _weeklyData = [];
  List<DayStats> _monthlyData = [];
  List<PracticeRecord> _records = [];
  List<PracticeGoal> _goals = [];
  int _weekTotal = 0;
  int _monthTotal = 0;
  int _recordTotal = 0;
  int _pendingSyncCount = 0;
  bool _isLoading = false;
  bool _isFlushingPending = false;
  bool _lastWriteQueued = false;
  String? _lastError;

  PracticeStats get stats => _stats;
  List<DayStats> get weeklyData => _weeklyData;
  List<DayStats> get monthlyData => _monthlyData;
  List<PracticeRecord> get records => _records;
  List<PracticeGoal> get goals => _goals;
  int get weekTotal => _weekTotal;
  int get monthTotal => _monthTotal;
  int get recordTotal => _recordTotal;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;
  bool get isFlushingPending => _isFlushingPending;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;
  bool get lastWriteQueued => _lastWriteQueued;
  String? get lastError => _lastError;

  void setAuthToken(String? token) {
    _authToken = token;
    _authUsername = _usernameFromToken(token);

    if (token == null || token.isEmpty) {
      _clearCloudData();
      notifyListeners();
      return;
    }

    _refreshPendingCount();
  }

  Future<String> get _baseUrl async => await AppSettings.getBackendUrl();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_authToken',
    'Content-Type': 'application/json',
  };

  String get _pendingRecordsKey =>
      'practice_pending_records_${_authUsername ?? 'unknown'}';

  void _clearCloudData() {
    _stats = PracticeStats.empty();
    _weeklyData = [];
    _monthlyData = [];
    _records = [];
    _goals = [];
    _weekTotal = 0;
    _monthTotal = 0;
    _recordTotal = 0;
    _pendingSyncCount = 0;
    _lastWriteQueued = false;
    _lastError = null;
  }

  Future<bool> _ensureAuthToken() async {
    if (_authToken != null && _authToken!.isNotEmpty) return true;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.tokenStorageKey);
    if (token == null || token.isEmpty) return false;

    _authToken = token;
    _authUsername = _usernameFromToken(token);
    await _refreshPendingCount();
    return true;
  }

  String? _usernameFromToken(String? token) {
    if (token == null || token.isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      return (payload['username'] ?? payload['sub'])?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingRecordsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final items = jsonDecode(raw) as List<dynamic>;
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('读取待同步修行记录失败: $e');
      await prefs.remove(_pendingRecordsKey);
      return [];
    }
  }

  Future<void> _savePendingRecords(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    if (records.isEmpty) {
      await prefs.remove(_pendingRecordsKey);
    } else {
      await prefs.setString(_pendingRecordsKey, jsonEncode(records));
    }
    _pendingSyncCount = records.length;
    notifyListeners();
  }

  Future<void> _refreshPendingCount() async {
    final records = await _loadPendingRecords();
    _pendingSyncCount = records.length;
    notifyListeners();
  }

  Future<void> _queuePendingRecord(Map<String, dynamic> body) async {
    final pending = await _loadPendingRecords();
    pending.add({...body, 'clientQueuedAt': DateTime.now().toIso8601String()});
    await _savePendingRecords(pending);
  }

  Future<bool> _postRecordBody(Map<String, dynamic> body) async {
    final url = await _baseUrl;
    final response = await http.post(
      Uri.parse('$url/api/meditation/record'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      _lastError = '云端保存失败: HTTP ${response.statusCode}';
      return false;
    }

    final data = jsonDecode(response.body);
    if (data['success'] == true) return true;

    _lastError = data['error']?.toString() ?? '云端保存失败';
    return false;
  }

  Future<void> _refreshAfterRecordMutation() async {
    await Future.wait([
      fetchStats(),
      fetchWeeklyStats(),
      fetchMonthlyStats(),
      fetchRecords(),
      fetchGoals(),
    ]);
  }

  Future<bool> flushPendingRecords() async {
    if (_isFlushingPending) return _pendingSyncCount == 0;
    if (!await _ensureAuthToken()) return false;

    final pending = await _loadPendingRecords();
    if (pending.isEmpty) {
      _pendingSyncCount = 0;
      notifyListeners();
      return true;
    }

    _isFlushingPending = true;
    notifyListeners();

    final remaining = <Map<String, dynamic>>[];
    for (final record in pending) {
      final body = Map<String, dynamic>.from(record)..remove('clientQueuedAt');
      try {
        final uploaded = await _postRecordBody(body);
        if (!uploaded) remaining.add(record);
      } catch (e) {
        _lastError = '待同步记录上传失败: $e';
        remaining.add(record);
      }
    }

    await _savePendingRecords(remaining);
    _isFlushingPending = false;
    notifyListeners();

    if (remaining.length != pending.length) {
      await _refreshAfterRecordMutation();
    }

    return remaining.isEmpty;
  }

  /// 获取修行统计概览
  Future<bool> fetchStats() async {
    if (!await _ensureAuthToken()) return false;

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
          _stats = PracticeStats.fromJson(
            Map<String, dynamic>.from(data['data'] ?? {}),
          );
          _lastError = null;
          return true;
        }
      }
      _lastError = '获取修行统计失败: HTTP ${response.statusCode}';
    } catch (e) {
      _lastError = '获取修行统计失败: $e';
      debugPrint(_lastError);
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return false;
  }

  /// 获取周统计数据
  Future<bool> fetchWeeklyStats() async {
    if (!await _ensureAuthToken()) return false;

    try {
      final url = await _baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/meditation/weekly'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final days = data['data']?['days'] as List<dynamic>?;
          _weeklyData =
              days
                  ?.map(
                    (e) =>
                        DayStats.fromJson(Map<String, dynamic>.from(e as Map)),
                  )
                  .toList() ??
              [];
          _weekTotal = _asInt(data['data']?['weekTotal']);
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
    if (!await _ensureAuthToken()) return false;

    try {
      final url = await _baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/meditation/monthly'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final days = data['data']?['days'] as List<dynamic>?;
          _monthlyData =
              days
                  ?.map(
                    (e) =>
                        DayStats.fromJson(Map<String, dynamic>.from(e as Map)),
                  )
                  .toList() ??
              [];
          _monthTotal = _asInt(data['data']?['monthTotal']);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('获取月统计失败: $e');
    }
    return false;
  }

  /// 获取云端修行记录列表
  Future<bool> fetchRecords({
    int limit = 50,
    int offset = 0,
    String? sutra,
  }) async {
    if (!await _ensureAuthToken()) return false;

    try {
      final url = await _baseUrl;
      final query = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (sutra != null && sutra.isNotEmpty) query['sutra'] = sutra;

      final uri = Uri.parse(
        '$url/api/meditation/records',
      ).replace(queryParameters: query);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final records = data['data']?['records'] as List<dynamic>?;
          _records =
              records
                  ?.map(
                    (e) => PracticeRecord.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList() ??
              [];
          _recordTotal = _asInt(data['data']?['total']);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('获取修行记录失败: $e');
    }
    return false;
  }

  /// 获取发愿目标
  Future<bool> fetchGoals() async {
    if (!await _ensureAuthToken()) return false;

    try {
      final url = await _baseUrl;
      final response = await http.get(
        Uri.parse('$url/api/meditation/goal'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final goals = data['data']?['goals'] as List<dynamic>?;
          _goals =
              goals
                  ?.map(
                    (e) => PracticeGoal.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList() ??
              [];
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
    if (!await _ensureAuthToken()) return false;

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
    String? localTime,
    String? notes,
  }) async {
    return _saveRecord(
      sutra: sutra,
      sutraSource: 'custom',
      chantCount: chantCount,
      duration: duration,
      isManual: true,
      recordDate: recordDate,
      localTime: localTime,
      notes: notes,
    );
  }

  /// 同步禅室修行记录
  Future<bool> syncRecord({
    required String sutra,
    String sutraSource = 'asset',
    required int chantCount,
    required int duration,
    DateTime? startTime,
    DateTime? endTime,
    String? localTime,
    String? notes,
  }) async {
    final dateSource = endTime ?? startTime ?? DateTime.now();
    return _saveRecord(
      sutra: sutra,
      sutraSource: sutraSource,
      chantCount: chantCount,
      duration: duration,
      isManual: false,
      recordDate: _formatRecordDate(dateSource),
      startTime: startTime,
      endTime: endTime,
      localTime: localTime ?? _formatLocalTime(dateSource),
      notes: notes,
    );
  }

  Future<bool> _saveRecord({
    required String sutra,
    required String sutraSource,
    required int chantCount,
    required int duration,
    required bool isManual,
    String? recordDate,
    DateTime? startTime,
    DateTime? endTime,
    String? localTime,
    String? notes,
  }) async {
    _lastWriteQueued = false;
    if (!await _ensureAuthToken()) return false;

    final body = <String, dynamic>{
      'sutra': sutra,
      'sutraSource': sutraSource,
      'chantCount': chantCount,
      'duration': duration,
      'isManual': isManual,
      'recordDate': recordDate ?? _formatRecordDate(DateTime.now()),
      'localTime':
          localTime ?? _formatLocalTime(endTime ?? startTime ?? DateTime.now()),
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'notes': notes ?? '',
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime.toIso8601String(),
    };

    try {
      final uploaded = await _postRecordBody(body);
      if (uploaded) {
        _lastError = null;
        await _refreshAfterRecordMutation();
        return true;
      }
    } catch (e) {
      _lastError = '云端保存修行记录失败: $e';
      debugPrint(_lastError);
    }

    _lastWriteQueued = true;
    await _queuePendingRecord(body);
    return true;
  }

  String _formatRecordDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatLocalTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// 加载所有云端数据
  Future<void> loadAllData() async {
    if (!await _ensureAuthToken()) {
      _clearCloudData();
      notifyListeners();
      return;
    }

    await flushPendingRecords();
    await Future.wait([
      fetchStats(),
      fetchWeeklyStats(),
      fetchMonthlyStats(),
      fetchRecords(),
      fetchGoals(),
    ]);
  }
}
