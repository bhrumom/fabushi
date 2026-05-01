import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 微成就系统 - 持续正向反馈
///
/// 设计理念：让用户每次进入禅室都能获得即时成就感
/// 华丽动画风格：金色光效、粒子特效、渐变发光
class AchievementSystem extends ChangeNotifier {
  static final AchievementSystem _instance = AchievementSystem._internal();
  factory AchievementSystem() => _instance;
  AchievementSystem._internal();

  final StreamController<Achievement> _achievementController =
      StreamController<Achievement>.broadcast();

  /// 成就事件流（用于UI监听并显示动画）
  Stream<Achievement> get achievementStream => _achievementController.stream;

  // 用户成就数据
  int _totalSessions = 0;
  int _totalMinutes = 0;
  int _totalChants = 0;
  int _consecutiveDays = 0;
  DateTime? _lastSessionDate;
  Set<String> _unlockedAchievements = {};
  bool _dataLoaded = false;

  // Getters
  int get totalSessions => _totalSessions;
  int get totalMinutes => _totalMinutes;
  int get totalChants => _totalChants;
  int get consecutiveDays => _consecutiveDays;

  /// 加载成就数据
  Future<void> loadData() async {
    if (_dataLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSessions = prefs.getInt('achievement_total_sessions') ?? 0;
      _totalMinutes = prefs.getInt('achievement_total_minutes') ?? 0;
      _totalChants = prefs.getInt('achievement_total_chants') ?? 0;
      _consecutiveDays = prefs.getInt('achievement_consecutive_days') ?? 0;

      final lastDateStr = prefs.getString('achievement_last_session_date');
      if (lastDateStr != null) {
        _lastSessionDate = DateTime.tryParse(lastDateStr);
      }

      final unlockedList = prefs.getStringList('achievement_unlocked') ?? [];
      _unlockedAchievements = unlockedList.toSet();

      _dataLoaded = true;
      debugPrint(
        '🏆 成就数据加载: 总会话=$_totalSessions, 总时长=$_totalMinutes分钟, 连续=$_consecutiveDays天',
      );
    } catch (e) {
      debugPrint('⚠️ 加载成就数据失败: $e');
    }
  }

  /// 保存成就数据
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('achievement_total_sessions', _totalSessions);
      await prefs.setInt('achievement_total_minutes', _totalMinutes);
      await prefs.setInt('achievement_total_chants', _totalChants);
      await prefs.setInt('achievement_consecutive_days', _consecutiveDays);

      if (_lastSessionDate != null) {
        await prefs.setString(
          'achievement_last_session_date',
          _lastSessionDate!.toIso8601String(),
        );
      }

      await prefs.setStringList(
        'achievement_unlocked',
        _unlockedAchievements.toList(),
      );
    } catch (e) {
      debugPrint('⚠️ 保存成就数据失败: $e');
    }
  }

  /// 检查并触发修行开始成就
  Future<void> onSessionStart() async {
    await loadData();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 检查是否是今日首次修行
    if (_lastSessionDate == null ||
        DateTime(
              _lastSessionDate!.year,
              _lastSessionDate!.month,
              _lastSessionDate!.day,
            ) !=
            today) {
      // 今日首次修行成就
      _triggerAchievement(
        Achievement(
          id: 'daily_start',
          title: '今日已开启修行',
          description: '迈出修行的第一步',
          icon: '🌅',
          tier: AchievementTier.bronze,
          animation: AchievementAnimation.sunrise,
        ),
      );

      // 检查连续天数
      if (_lastSessionDate != null) {
        final yesterday = today.subtract(const Duration(days: 1));
        final lastDate = DateTime(
          _lastSessionDate!.year,
          _lastSessionDate!.month,
          _lastSessionDate!.day,
        );

        if (lastDate == yesterday) {
          _consecutiveDays++;
          _checkConsecutiveDaysAchievements();
        } else if (lastDate != today) {
          _consecutiveDays = 1; // 重置连续天数
        }
      } else {
        _consecutiveDays = 1;
      }

      _lastSessionDate = now;
    }

    // 检查特殊时间成就
    _checkTimeBasedAchievements(now);

    await _saveData();
    notifyListeners();
  }

  /// 检查并触发修行结束成就
  Future<void> onSessionEnd({
    required Duration duration,
    required int chantCount,
    required String sutra,
  }) async {
    await loadData();

    _totalSessions++;
    _totalMinutes += duration.inMinutes;
    _totalChants += chantCount;

    // 首次完成成就
    if (_totalSessions == 1) {
      _triggerAchievement(
        Achievement(
          id: 'first_session',
          title: '初心不改',
          description: '完成首次修行',
          icon: '✨',
          tier: AchievementTier.gold,
          animation: AchievementAnimation.sparkle,
        ),
      );
    }

    // 时长里程碑
    _checkDurationMilestones(duration);

    // 念诵里程碑
    _checkChantMilestones(chantCount);

    // 累计会话里程碑
    _checkSessionMilestones();

    // 累计时长里程碑
    _checkTotalMinutesMilestones();

    await _saveData();
    notifyListeners();
  }

  /// 检查连续天数成就
  void _checkConsecutiveDaysAchievements() {
    final milestones = {
      3: Achievement(
        id: 'streak_3',
        title: '三日精进',
        description: '连续修行3天',
        icon: '🔥',
        tier: AchievementTier.bronze,
        animation: AchievementAnimation.flame,
      ),
      7: Achievement(
        id: 'streak_7',
        title: '七日不辍',
        description: '连续修行7天',
        icon: '🌟',
        tier: AchievementTier.silver,
        animation: AchievementAnimation.starBurst,
      ),
      21: Achievement(
        id: 'streak_21',
        title: '习惯养成',
        description: '连续修行21天',
        icon: '💎',
        tier: AchievementTier.gold,
        animation: AchievementAnimation.diamond,
      ),
      30: Achievement(
        id: 'streak_30',
        title: '一月精修',
        description: '连续修行30天',
        icon: '🏆',
        tier: AchievementTier.platinum,
        animation: AchievementAnimation.trophy,
      ),
      100: Achievement(
        id: 'streak_100',
        title: '百日筑基',
        description: '连续修行100天',
        icon: '👑',
        tier: AchievementTier.legendary,
        animation: AchievementAnimation.crown,
      ),
    };

    for (final entry in milestones.entries) {
      if (_consecutiveDays == entry.key &&
          !_unlockedAchievements.contains(entry.value.id)) {
        _triggerAchievement(entry.value);
      }
    }
  }

  /// 检查特殊时间成就
  void _checkTimeBasedAchievements(DateTime time) {
    // 子时修行 (23:00 - 01:00)
    if ((time.hour >= 23 || time.hour < 1) &&
        !_unlockedAchievements.contains('midnight_practice')) {
      _triggerAchievement(
        Achievement(
          id: 'midnight_practice',
          title: '子时修行',
          description: '在子时开始修行',
          icon: '🌙',
          tier: AchievementTier.silver,
          animation: AchievementAnimation.moonGlow,
        ),
      );
    }

    // 清晨早课 (05:00 - 07:00)
    if (time.hour >= 5 &&
        time.hour < 7 &&
        !_unlockedAchievements.contains('morning_practice')) {
      _triggerAchievement(
        Achievement(
          id: 'morning_practice',
          title: '清晨早课',
          description: '在清晨开始修行',
          icon: '🌄',
          tier: AchievementTier.silver,
          animation: AchievementAnimation.sunrise,
        ),
      );
    }
  }

  /// 检查单次时长里程碑
  void _checkDurationMilestones(Duration duration) {
    final milestones = {
      5: Achievement(
        id: 'duration_5',
        title: '五分精进',
        description: '单次修行5分钟',
        icon: '⏱️',
        tier: AchievementTier.bronze,
        animation: AchievementAnimation.pulse,
      ),
      30: Achievement(
        id: 'duration_30',
        title: '半时功德',
        description: '单次修行30分钟',
        icon: '⏳',
        tier: AchievementTier.silver,
        animation: AchievementAnimation.hourglass,
      ),
      60: Achievement(
        id: 'duration_60',
        title: '一时圆满',
        description: '单次修行60分钟',
        icon: '🕐',
        tier: AchievementTier.gold,
        animation: AchievementAnimation.clockChime,
      ),
    };

    for (final entry in milestones.entries) {
      if (duration.inMinutes >= entry.key &&
          !_unlockedAchievements.contains(entry.value.id)) {
        _triggerAchievement(entry.value);
      }
    }
  }

  /// 检查念诵里程碑
  void _checkChantMilestones(int chantCount) {
    if (chantCount >= 108 && !_unlockedAchievements.contains('chant_108')) {
      _triggerAchievement(
        Achievement(
          id: 'chant_108',
          title: '一百零八遍',
          description: '单次念诵108遍',
          icon: '📿',
          tier: AchievementTier.gold,
          animation: AchievementAnimation.mala,
        ),
      );
    }
  }

  /// 检查累计会话里程碑
  void _checkSessionMilestones() {
    final milestones = {
      10: Achievement(
        id: 'sessions_10',
        title: '十次精进',
        description: '累计修行10次',
        icon: '🎯',
        tier: AchievementTier.bronze,
        animation: AchievementAnimation.target,
      ),
      50: Achievement(
        id: 'sessions_50',
        title: '五十功德',
        description: '累计修行50次',
        icon: '🎖️',
        tier: AchievementTier.silver,
        animation: AchievementAnimation.medal,
      ),
      100: Achievement(
        id: 'sessions_100',
        title: '百次圆满',
        description: '累计修行100次',
        icon: '🏅',
        tier: AchievementTier.gold,
        animation: AchievementAnimation.goldMedal,
      ),
    };

    for (final entry in milestones.entries) {
      if (_totalSessions == entry.key &&
          !_unlockedAchievements.contains(entry.value.id)) {
        _triggerAchievement(entry.value);
      }
    }
  }

  /// 检查累计时长里程碑
  void _checkTotalMinutesMilestones() {
    final milestones = {
      60: Achievement(
        id: 'total_60min',
        title: '累计一小时',
        description: '累计修行60分钟',
        icon: '⌛',
        tier: AchievementTier.bronze,
        animation: AchievementAnimation.hourglass,
      ),
      600: Achievement(
        id: 'total_10hr',
        title: '累计十小时',
        description: '累计修行10小时',
        icon: '🌟',
        tier: AchievementTier.silver,
        animation: AchievementAnimation.starBurst,
      ),
      6000: Achievement(
        id: 'total_100hr',
        title: '累计百时',
        description: '累计修行100小时',
        icon: '💫',
        tier: AchievementTier.platinum,
        animation: AchievementAnimation.cosmic,
      ),
    };

    for (final entry in milestones.entries) {
      if (_totalMinutes >= entry.key &&
          !_unlockedAchievements.contains(entry.value.id)) {
        _triggerAchievement(entry.value);
      }
    }
  }

  /// 触发成就
  void _triggerAchievement(Achievement achievement) {
    if (_unlockedAchievements.contains(achievement.id)) return;

    _unlockedAchievements.add(achievement.id);
    _achievementController.add(achievement);

    debugPrint('🏆 成就解锁: ${achievement.title}');
  }

  /// 获取所有已解锁成就
  List<String> get unlockedAchievements => _unlockedAchievements.toList();

  /// 检查成就是否已解锁
  bool isUnlocked(String achievementId) =>
      _unlockedAchievements.contains(achievementId);

  @override
  void dispose() {
    _achievementController.close();
    super.dispose();
  }
}

/// 成就等级
enum AchievementTier {
  bronze, // 铜
  silver, // 银
  gold, // 金
  platinum, // 白金
  legendary, // 传说
}

/// 成就动画类型
enum AchievementAnimation {
  sunrise, // 日出动画
  sparkle, // 闪烁星光
  flame, // 火焰燃烧
  starBurst, // 星爆
  diamond, // 钻石闪烁
  trophy, // 奖杯升起
  crown, // 皇冠降临
  moonGlow, // 月光笼罩
  pulse, // 脉冲扩散
  hourglass, // 沙漏流转
  clockChime, // 时钟敲响
  mala, // 念珠转动
  target, // 命中靶心
  medal, // 勋章授予
  goldMedal, // 金牌闪耀
  cosmic, // 宇宙光效
}

/// 成就数据
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final AchievementTier tier;
  final AchievementAnimation animation;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
    required this.animation,
    this.unlockedAt,
  });

  /// 获取等级颜色
  int get tierColor {
    switch (tier) {
      case AchievementTier.bronze:
        return 0xFFCD7F32;
      case AchievementTier.silver:
        return 0xFFC0C0C0;
      case AchievementTier.gold:
        return 0xFFFFD700;
      case AchievementTier.platinum:
        return 0xFFE5E4E2;
      case AchievementTier.legendary:
        return 0xFF9400D3;
    }
  }

  /// 获取等级名称
  String get tierName {
    switch (tier) {
      case AchievementTier.bronze:
        return '铜';
      case AchievementTier.silver:
        return '银';
      case AchievementTier.gold:
        return '金';
      case AchievementTier.platinum:
        return '白金';
      case AchievementTier.legendary:
        return '传说';
    }
  }
}
