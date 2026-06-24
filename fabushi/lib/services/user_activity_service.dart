import 'package:flutter/foundation.dart';
import '../models/user_activity_stats_model.dart';
import '../models/auth_model.dart';
import '../services/practice_stats_service.dart';
import '../services/local_ai_conversation_store.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';

class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();

  factory UserActivityService() {
    return _instance;
  }

  UserActivityService._internal();

  /// Estimate token usage based on local chat messages length
  int _estimateTokenCount(String text) {
    // Basic estimation: Chinese character is roughly 1 token, English word is ~1 token
    return text.length;
  }

  /// Fetches real activity stats by combining local conversation store and remote practice stats
  Future<UserActivitySummary> fetchActivityStats(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. Initialize empty 365-day map
    final Map<DateTime, UserActivityMetric> dailyMap = {};
    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      dailyMap[date] = UserActivityMetric(
        date: date,
        tokenCount: 0,
        meditationMinutes: 0,
        dharmaDataMB: 0,
      );
    }

    // 2. Load Local AI Token Usage
    try {
      final records = await LocalAiConversationStore.instance.list();
      for (final record in records) {
        for (final msg in record.messages) {
          final dateStr = msg.createdAt.toIso8601String().split('T')[0];
          final date = DateTime.parse(dateStr);
          final dayStart = DateTime(date.year, date.month, date.day);
          
          if (dailyMap.containsKey(dayStart)) {
            final tokens = _estimateTokenCount(msg.content);
            final existing = dailyMap[dayStart]!;
            dailyMap[dayStart] = UserActivityMetric(
              date: existing.date,
              tokenCount: existing.tokenCount + tokens,
              meditationMinutes: existing.meditationMinutes,
              dharmaDataMB: existing.dharmaDataMB,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load local AI tokens: $e');
    }

    // 3. Load Remote Practice Stats
    try {
      final authModel = context.read<AuthModel>();
      final token = authModel.authToken;
      if (token != null) {
        final practiceService = PracticeStatsService();
        final List<DayStats> dayStats = practiceService.monthlyData;
        final List<DayStats> weeklyStats = practiceService.weeklyData;
        
        // Combine all known day stats
        final allKnownStats = [...dayStats, ...weeklyStats];
        for (final stat in allKnownStats) {
          final dateStr = stat.date; // format YYYY-MM-DD
          try {
            final date = DateTime.parse(dateStr);
            final dayStart = DateTime(date.year, date.month, date.day);
            if (dailyMap.containsKey(dayStart)) {
              final existing = dailyMap[dayStart]!;
              dailyMap[dayStart] = UserActivityMetric(
                date: existing.date,
                tokenCount: existing.tokenCount,
                meditationMinutes: stat.duration, // Note: stat.duration is total for the day
                dharmaDataMB: existing.dharmaDataMB,
              );
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Failed to load practice stats: $e');
    }

    // 4. Transform to list and sort ascending for the UI
    final List<UserActivityMetric> dailyMetrics = dailyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // 5. Generate Weekly aggregation
    List<UserActivityMetric> weeklyMetrics = [];
    for (int i = 0; i < dailyMetrics.length; i += 7) {
      final weekChunk = dailyMetrics.skip(i).take(7).toList();
      final endOfWeek = weekChunk.last.date;
      
      int weeklyTokens = weekChunk.fold(0, (sum, m) => sum + m.tokenCount);
      int weeklyMeditation = weekChunk.fold(0, (sum, m) => sum + m.meditationMinutes);
      double weeklyDharma = weekChunk.fold(0.0, (sum, m) => sum + m.dharmaDataMB);

      weeklyMetrics.add(UserActivityMetric(
        date: endOfWeek,
        tokenCount: weeklyTokens,
        meditationMinutes: weeklyMeditation,
        dharmaDataMB: weeklyDharma,
      ));
    }

    // 6. Generate Cumulative aggregation
    List<UserActivityMetric> cumulativeMetrics = [];
    int totalTokens = 0;
    int totalMeditation = 0;
    double totalDharma = 0;

    for (int i = 0; i < dailyMetrics.length; i++) {
      final day = dailyMetrics[i];
      totalTokens += day.tokenCount;
      totalMeditation += day.meditationMinutes;
      totalDharma += day.dharmaDataMB;

      cumulativeMetrics.add(UserActivityMetric(
        date: day.date,
        tokenCount: totalTokens,
        meditationMinutes: totalMeditation,
        dharmaDataMB: totalDharma,
      ));
    }

    return UserActivitySummary(
      dailyMetrics: dailyMetrics,
      weeklyMetrics: weeklyMetrics,
      cumulativeMetrics: cumulativeMetrics,
    );
  }
}
