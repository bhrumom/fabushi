class UserActivityMetric {
  final DateTime date;
  final int tokenCount;
  final int meditationMinutes;
  final double dharmaDataMB;

  UserActivityMetric({
    required this.date,
    required this.tokenCount,
    required this.meditationMinutes,
    required this.dharmaDataMB,
  });

  factory UserActivityMetric.empty(DateTime date) {
    return UserActivityMetric(
      date: date,
      tokenCount: 0,
      meditationMinutes: 0,
      dharmaDataMB: 0,
    );
  }
}

class UserActivitySummary {
  final List<UserActivityMetric> dailyMetrics;
  final List<UserActivityMetric> weeklyMetrics;
  final List<UserActivityMetric> cumulativeMetrics;

  UserActivitySummary({
    required this.dailyMetrics,
    required this.weeklyMetrics,
    required this.cumulativeMetrics,
  });

  factory UserActivitySummary.empty() {
    return UserActivitySummary(
      dailyMetrics: [],
      weeklyMetrics: [],
      cumulativeMetrics: [],
    );
  }
}
