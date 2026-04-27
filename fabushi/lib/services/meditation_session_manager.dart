import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../models/meditation_practice_model.dart';
import 'http_service.dart';

/// 禅室会话管理器 - 零摩擦修行核心
/// 
/// 设计原则：
/// - 2分钟法则：降低启动门槛到微不足道
/// - 原子习惯：智能默认，让修行不可能不做
/// - 心流理论：渐进式体验，持续正向反馈
class MeditationSessionManager extends ChangeNotifier {
  static final MeditationSessionManager _instance = MeditationSessionManager._internal();
  factory MeditationSessionManager() => _instance;
  MeditationSessionManager._internal();

  // ========== 状态 ==========
  bool _isInSession = false;
  Duration _currentDuration = Duration.zero;
  String? _currentSutra;
  int _chantCount = 0;
  DateTime? _sessionStartTime;
  Timer? _durationTimer;
  
  // 用户偏好
  String? _lastSutra;
  int _preferredDurationMinutes = 30; // 软性建议，非强制
  bool _preferencesLoaded = false;
  String? _currentUsername;
  
  // ========== 锁定功课 ==========
  MeditationPractice? _lockedPractice;

  // ========== Getters ==========
  bool get isInSession => _isInSession;
  Duration get currentDuration => _currentDuration;
  String get currentSutra => _currentSutra ?? _lockedPractice?.title ?? _lastSutra ?? '默认功课';
  int get chantCount => _chantCount;
  String? get lastSutra => _lastSutra;
  int get preferredDurationMinutes => _preferredDurationMinutes;
  bool get hasLastSutra => _lastSutra != null && _lastSutra!.isNotEmpty;
  
  // ========== 锁定功课 Getters ==========
  /// 是否已锁定功课
  bool get isPracticeLocked => _lockedPractice != null && _lockedPractice!.isLocked;
  
  /// 获取锁定的功课
  MeditationPractice? get lockedPractice => _lockedPractice;
  
  /// 是否可以开始修行（需要已锁定功课）
  bool get canStartSession => isPracticeLocked;
  String? get currentUsername => _currentUsername;

  // 进度百分比（基于软性目标）
  double get progressPercent {
    if (_preferredDurationMinutes <= 0) return 0;
    return (_currentDuration.inSeconds / (_preferredDurationMinutes * 60)).clamp(0.0, 1.0);
  }

  // ========== 初始化 ==========

  String _storageKey(String baseKey) {
    final username = _currentUsername;
    if (username == null || username.isEmpty) return '${baseKey}_guest';
    return '${baseKey}_user_$username';
  }

  /// 切换当前账号并加载对应云端/本地主修功课。
  Future<void> switchUser(String? username) async {
    if (_currentUsername == username && _preferencesLoaded) {
      if (username != null && username.isNotEmpty) {
        await refreshPracticeFromCloud();
      }
      return;
    }

    _durationTimer?.cancel();
    _isInSession = false;
    _currentDuration = Duration.zero;
    _currentSutra = null;
    _chantCount = 0;
    _sessionStartTime = null;
    _lastSutra = null;
    _lockedPractice = null;
    _currentUsername = username;
    _preferencesLoaded = false;

    if (username == null || username.isEmpty) {
      debugPrint('🧘 禅室已切换到未登录状态');
      notifyListeners();
      return;
    }

    await loadPreferences();
    await refreshPracticeFromCloud();
    notifyListeners();
  }
  
  /// 加载用户偏好（应在app启动时调用）
  Future<void> loadPreferences() async {
    if (_preferencesLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSutra = prefs.getString(_storageKey('zen_last_sutra'));
      _preferredDurationMinutes = prefs.getInt(_storageKey('zen_preferred_duration')) ?? 30;
      
      // 加载锁定的功课
      final practiceJson = prefs.getString(_storageKey('zen_locked_practice'));
      if (practiceJson != null) {
        try {
          _lockedPractice = MeditationPractice.fromJson(jsonDecode(practiceJson));
          debugPrint('🧘 已加载锁定功课: ${_lockedPractice?.title}');
        } catch (e) {
          debugPrint('⚠️ 解析锁定功课失败: $e');
        }
      }
      
      _preferencesLoaded = true;
      debugPrint('🧘 禅室偏好加载: 用户=$_currentUsername, 上次功课=$_lastSutra, 锁定功课=${_lockedPractice?.title}, 建议时长=$_preferredDurationMinutes分钟');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ 加载禅室偏好失败: $e');
    }
  }

  /// 保存用户偏好
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentSutra != null) {
        await prefs.setString(_storageKey('zen_last_sutra'), _currentSutra!);
        _lastSutra = _currentSutra;
      }
      await prefs.setInt(_storageKey('zen_preferred_duration'), _preferredDurationMinutes);
      
      // 保存锁定的功课
      if (_lockedPractice != null) {
        await prefs.setString(_storageKey('zen_locked_practice'), jsonEncode(_lockedPractice!.toJson()));
      }
      
      debugPrint('🧘 禅室偏好已保存');
    } catch (e) {
      debugPrint('⚠️ 保存禅室偏好失败: $e');
    }
  }
  
  /// 选择并锁定功课（一旦锁定不可更改）
  Future<bool> selectAndLockPractice(String title, String filePath) async {
    if (_lockedPractice != null) {
      debugPrint('🧘 功课已锁定，无法更改: ${_lockedPractice!.title}');
      return false;
    }
    
    _lockedPractice = MeditationPractice(
      title: title,
      filePath: filePath,
      selectedAt: DateTime.now(),
      isLocked: true,
    );
    
    await _savePreferences();
    await _syncLockedPracticeToCloud();
    debugPrint('🧘 功课已锁定: $title ($filePath)');
    notifyListeners();
    return true;
  }

  Future<void> refreshPracticeFromCloud() async {
    if (_currentUsername == null || _currentUsername!.isEmpty) return;

    try {
      final response = await HttpService.get(AppConfig.userInfoUrl, useAuth: true);
      if (response.statusCode != 200) {
        debugPrint('⚠️ 拉取云端主修功课失败: HTTP ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      final cloudPractice = data['mainPractice'];
      if (cloudPractice is Map && cloudPractice['title'] != null) {
        final title = cloudPractice['title'].toString();
        _lockedPractice = MeditationPractice(
          title: title,
          filePath: (cloudPractice['filePath'] ?? 'manual:${Uri.encodeComponent(title)}').toString(),
          selectedAt: DateTime.tryParse((cloudPractice['selectedAt'] ?? '').toString()) ?? DateTime.now(),
          isLocked: true,
        );
        await _savePreferences();
        debugPrint('☁️ 已从云端加载主修功课: ${_lockedPractice?.title}');
        notifyListeners();
      } else if (_lockedPractice != null) {
        await _syncLockedPracticeToCloud();
      }
    } catch (e) {
      debugPrint('⚠️ 同步云端主修功课失败: $e');
    }
  }

  Future<void> _syncLockedPracticeToCloud() async {
    if (_currentUsername == null || _currentUsername!.isEmpty || _lockedPractice == null) return;

    try {
      final response = await HttpService.post(
        '${AppConfig.apiUrl}/api/auth/update-profile',
        body: {
          'mainPractice': _lockedPractice!.toJson(),
        },
        useAuth: true,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('☁️ 主修功课已保存到云端: ${_lockedPractice!.title}');
      } else {
        debugPrint('⚠️ 保存云端主修功课失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ 保存云端主修功课异常: $e');
    }
  }

  // ========== 核心操作 ==========

  /// 即时开始修行（零摩擦入口）
  /// 自动使用上次功课，无需用户选择
  Future<void> instantStart({String? sutra}) async {
    if (_isInSession) {
      debugPrint('🧘 已在修行中，忽略重复开始');
      return;
    }

    // 确保偏好已加载
    await loadPreferences();

    // 智能选择功课：优先使用传入的 > 上次的 > 默认
    _currentSutra = sutra ?? _lastSutra ?? '默认功课';
    _isInSession = true;
    _chantCount = 0;
    _currentDuration = Duration.zero;
    _sessionStartTime = DateTime.now();

    // 启动计时器
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration += const Duration(seconds: 1);
      notifyListeners();
    });

    debugPrint('🧘 修行开始: $_currentSutra');
    notifyListeners();
  }

  /// 更换功课（会话中可随时更换）
  void changeSutra(String sutra) {
    _currentSutra = sutra;
    notifyListeners();
  }

  /// 增加念诵计数
  void incrementChant({int count = 1}) {
    _chantCount += count;
    notifyListeners();
  }

  /// 结束修行（可随时结束，无最低时长要求）
  Future<SessionResult> endSession() async {
    if (!_isInSession) {
      return SessionResult(
        success: false,
        message: '没有进行中的修行',
      );
    }

    _durationTimer?.cancel();
    _isInSession = false;

    final result = SessionResult(
      success: true,
      sutra: _currentSutra ?? '默认功课',
      duration: _currentDuration,
      chantCount: _chantCount,
      startTime: _sessionStartTime,
      endTime: DateTime.now(),
    );

    // 保存偏好（记住这次的功课）
    await _savePreferences();

    debugPrint('🧘 修行结束: ${result.sutra}, 时长${result.duration.inMinutes}分钟, 念诵${result.chantCount}遍');
    notifyListeners();

    return result;
  }

  /// 暂停修行（保留进度）
  void pauseSession() {
    _durationTimer?.cancel();
    debugPrint('🧘 修行暂停');
  }

  /// 恢复修行
  void resumeSession() {
    if (!_isInSession) return;
    
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration += const Duration(seconds: 1);
      notifyListeners();
    });
    debugPrint('🧘 修行恢复');
  }

  /// 设置建议时长（软性目标）
  void setPreferredDuration(int minutes) {
    _preferredDurationMinutes = minutes;
    _savePreferences();
    notifyListeners();
  }

  /// 重置状态（用于清理）
  void reset() {
    _durationTimer?.cancel();
    _isInSession = false;
    _currentDuration = Duration.zero;
    _chantCount = 0;
    _sessionStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }
}

/// 修行会话结果
class SessionResult {
  final bool success;
  final String? sutra;
  final Duration duration;
  final int chantCount;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? message;

  SessionResult({
    required this.success,
    this.sutra,
    this.duration = Duration.zero,
    this.chantCount = 0,
    this.startTime,
    this.endTime,
    this.message,
  });

  /// 是否达到建议时长
  bool get reachedSuggestedDuration => duration.inMinutes >= 30;

  /// 格式化时长
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'sutra': sutra,
    'duration': duration.inMinutes,
    'chantCount': chantCount,
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
  };
}
