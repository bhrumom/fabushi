import 'package:flutter/material.dart';
import '../services/practice_stats_service.dart';

/// 修行统计卡片 - 一念计数风格
class PracticeStatsCard extends StatefulWidget {
  final VoidCallback? onTapRecord; // 补录功课
  final VoidCallback? onTapHistory; // 查看记录
  final VoidCallback? onTapDedication; // 发愿回向
  final VoidCallback? onTapSettings; // 功课设置

  const PracticeStatsCard({
    super.key,
    this.onTapRecord,
    this.onTapHistory,
    this.onTapDedication,
    this.onTapSettings,
  });

  @override
  State<PracticeStatsCard> createState() => _PracticeStatsCardState();
}

class _PracticeStatsCardState extends State<PracticeStatsCard> {
  bool _showWeekly = true; // true=周, false=月
  final _service = PracticeStatsService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _service.loadAllData();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final stats = _service.stats;
        final goals = _service.goals;
        final periodData = _showWeekly
            ? _service.weeklyData
            : _service.monthlyData;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // 顶部统计卡片 - 红色渐变背景
              _buildHeaderCard(stats),

              // 功能按钮
              _buildActionButtons(),

              // 云端保存状态
              _buildCloudStatus(),

              // 发愿目标进度
              if (goals.isNotEmpty) _buildGoalProgress(goals.first),

              // 周/月统计
              _buildPeriodStats(periodData),

              // 快速分析
              _buildAnalysisPanel(stats, periodData),

              // 连续打卡
              _buildStreakInfo(stats.consecutiveDays),
            ],
          ),
        );
      },
    );
  }

  /// 顶部红色统计卡片
  Widget _buildHeaderCard(PracticeStats stats) {
    final durationText = _formatDuration(stats.total.duration);
    final averagePerDay = stats.total.days > 0
        ? (stats.total.count / stats.total.days).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 编辑图标和功课名
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.cloud_done_outlined,
                color: Colors.white70,
                size: 18,
              ),
              Expanded(
                child: Text(
                  stats.today.sutra ?? '今日尚未记录',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 18),
            ],
          ),
          const SizedBox(height: 12),

          // 今日修行数
          Text(
            '${stats.today.count}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.bold,
              letterSpacing: -2,
            ),
          ),
          const Text(
            '今日',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),

          const SizedBox(height: 20),

          // 累计统计
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('${stats.total.count}', '累计(部)'),
              _buildStatColumn(durationText, '总时长'),
              _buildStatColumn('$averagePerDay', '日均(部)'),
            ],
          ),

          const SizedBox(height: 16),

          // 查看报告和榜单按钮
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onTapHistory,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('查看报告'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('修行榜单功能开发中')));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('查看榜单'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  /// 功能按钮行
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            Icons.add_box_outlined,
            '补录功课',
            widget.onTapRecord,
          ),
          _buildActionButton(Icons.history, '查改记录', widget.onTapHistory),
          _buildActionButton(
            Icons.spa_outlined,
            '发愿回向',
            widget.onTapDedication,
          ),
          _buildActionButton(
            Icons.settings_outlined,
            '功课设置',
            widget.onTapSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudStatus() {
    final pendingCount = _service.pendingSyncCount;
    final isPending = pendingCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPending
                ? Colors.orange.withValues(alpha: 0.35)
                : Colors.green.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPending ? Icons.cloud_sync_outlined : Icons.cloud_done_outlined,
              color: isPending ? Colors.orange : Colors.green,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPending ? '有 $pendingCount 条记录待同步到云端' : '修行记录已保存于云端',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            if (isPending)
              TextButton(
                onPressed: () => _service.flushPendingRecords(),
                child: const Text('同步', style: TextStyle(color: Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }

  /// 发愿目标进度
  Widget _buildGoalProgress(PracticeGoal goal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '发愿目标: ${goal.currentCount} / ${_formatNumber(goal.targetCount)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                '${goal.progress}%',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE74C3C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 周/月统计图表
  Widget _buildPeriodStats(List<DayStats> periodData) {
    final periodTotal = _showWeekly ? _service.weekTotal : _service.monthTotal;
    final maxCount = periodData.fold<int>(
      0,
      (max, day) => day.count > max ? day.count : max,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '本${_showWeekly ? "周" : "月"}: $periodTotal',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildPeriodToggle('周', _showWeekly, () {
                      setState(() => _showWeekly = true);
                      _service.fetchWeeklyStats();
                    }),
                    _buildPeriodToggle('月', !_showWeekly, () {
                      setState(() => _showWeekly = false);
                      _service.fetchMonthlyStats();
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 柱状图
          SizedBox(
            height: 120,
            child: periodData.isEmpty
                ? const Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: periodData
                          .map(
                            (day) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _buildBar(day, maxCount),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE74C3C) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBar(DayStats day, int maxCount) {
    final ratio = maxCount > 0 ? day.count / maxCount : 0.0;
    final height = 80 * ratio + 10; // 最小高度10

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${day.count}',
          style: TextStyle(
            color: day.count > 0 ? Colors.white : Colors.white38,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            gradient: day.count > 0
                ? const LinearGradient(
                    colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: day.count == 0 ? const Color(0xFF2A2A2A) : null,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDateLabel(day),
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildAnalysisPanel(PracticeStats stats, List<DayStats> periodData) {
    final topSubject = stats.bySubject.isNotEmpty
        ? stats.bySubject.first
        : null;
    final activeDays = periodData.where((day) => day.count > 0).length;
    final bestDay = periodData.isEmpty
        ? null
        : periodData.reduce((best, day) => day.count > best.count ? day : best);
    final averageDuration = stats.total.records > 0
        ? (stats.total.duration / stats.total.records).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快速分析',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInsightTile(
                    Icons.auto_stories_outlined,
                    '主修功课',
                    topSubject?.sutraName.isNotEmpty == true
                        ? topSubject!.sutraName
                        : '暂无',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInsightTile(
                    Icons.calendar_month_outlined,
                    _showWeekly ? '本周活跃' : '本月活跃',
                    '$activeDays 天',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInsightTile(
                    Icons.trending_up_outlined,
                    '最高一天',
                    bestDay == null
                        ? '暂无'
                        : '${_formatDateLabel(bestDay)} ${bestDay.count} 部',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInsightTile(
                    Icons.timer_outlined,
                    '单次均时',
                    averageDuration > 0 ? '$averageDuration 分钟' : '暂无',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightTile(IconData icon, String label, String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE74C3C), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 连续打卡信息
  Widget _buildStreakInfo(int consecutiveDays) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Color(0xFFE74C3C),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '报数记录: 您已连续打卡 $consecutiveDays 天',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(0)}万';
    }
    return number.toString();
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes / 60;
      return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h';
    }
    return '${minutes}m';
  }

  String _formatDateLabel(DayStats day) {
    if (_showWeekly && day.day.isNotEmpty) return '周${day.day}';
    return day.date.length >= 10 ? day.date.substring(5) : day.date;
  }
}
