import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../services/practice_stats_service.dart';
import '../widgets/practice_dialogs.dart';
import '../widgets/practice_stats_card.dart';

/// 修行记录页面 - 云端统计与记录分析
class PracticeRecordScreen extends StatefulWidget {
  const PracticeRecordScreen({super.key});

  @override
  State<PracticeRecordScreen> createState() => _PracticeRecordScreenState();
}

class _PracticeRecordScreenState extends State<PracticeRecordScreen> {
  final _service = PracticeStatsService();
  final _scrollController = ScrollController();
  final _recordsKey = GlobalKey();
  String? _loadedToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final authModel = context.read<AuthModel>();
    if (!authModel.isLoggedIn || authModel.authToken == null) return;

    _loadedToken = authModel.authToken;
    _service.setAuthToken(authModel.authToken);
    await _service.loadAllData();
  }

  void _scrollToRecords() {
    final context = _recordsKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String? get _defaultSutra {
    final stats = _service.stats;
    if (stats.today.sutra?.isNotEmpty == true) return stats.today.sutra;
    if (stats.bySubject.isNotEmpty) return stats.bySubject.first.sutraName;
    return null;
  }

  Future<void> _showAddRecordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AddPracticeRecordDialog(initialSutra: _defaultSutra),
    );
    if (changed == true) await _loadData();
  }

  Future<void> _showGoalDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => SetGoalDialog(initialSutra: _defaultSutra),
    );
    if (changed == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthModel>(
      builder: (context, authModel, _) {
        if (authModel.authToken != null &&
            authModel.authToken != _loadedToken) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
        }

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            title: const Text(
              '修行记录',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: '刷新',
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadData,
              ),
            ],
          ),
          body: authModel.isLoggedIn
              ? _buildRecordBody()
              : _buildLoginRequired(),
        );
      },
    );
  }

  Widget _buildRecordBody() {
    return RefreshIndicator(
      color: const Color(0xFFE74C3C),
      onRefresh: _loadData,
      child: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          final stats = _service.stats;

          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PracticeStatsCard(
                  onTapRecord: _showAddRecordDialog,
                  onTapHistory: _scrollToRecords,
                  onTapDedication: _showGoalDialog,
                  onTapSettings: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('功课设置请在禅室中查看当前功课')),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildCloudSummary(),
                const SizedBox(height: 16),
                _buildSubjectBreakdown(stats.bySubject),
                const SizedBox(height: 16),
                _buildRecentRecords(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCloudSummary() {
    final pending = _service.pendingSyncCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            pending > 0 ? Icons.cloud_sync_outlined : Icons.cloud_done_outlined,
            color: pending > 0 ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pending > 0 ? '$pending 条记录等待云端同步' : '云端记录已同步',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (pending > 0)
            TextButton(
              onPressed: () async {
                await _service.flushPendingRecords();
                await _loadData();
              },
              child: const Text('立即同步', style: TextStyle(color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectBreakdown(List<SubjectStats> subjects) {
    final topSubjects = subjects.take(5).toList();
    final maxCount = topSubjects.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '功课分布',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (topSubjects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '暂无云端修行记录',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            )
          else
            ...topSubjects.map((subject) {
              final ratio = maxCount > 0 ? subject.count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.sutraName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${subject.count} 部 · ${subject.days} 天',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
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
            }),
        ],
      ),
    );
  }

  Widget _buildRecentRecords() {
    final records = _service.records;

    return Container(
      key: _recordsKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '最近记录',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '云端 ${_service.recordTotal} 条',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('暂无记录', style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            ...records.take(20).map(_buildRecordTile),
        ],
      ),
    );
  }

  Widget _buildRecordTile(PracticeRecord record) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRecordDetail(record),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.self_improvement,
                  color: Color(0xFFE74C3C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.sutraName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildRecordSourceChip(record.sourceLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${record.dateTimeLabel} · ${record.chantCount} 部 · ${_formatDuration(record.duration)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    if (record.notes != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '心得：${record.notes!}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordDetail(PracticeRecord record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '修行详情',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _detailRow(label: '功课', value: record.sutraName),
                _detailRow(label: '时间', value: record.dateTimeLabel),
                _detailRow(
                  label: '修行时长',
                  value: _formatDuration(record.duration),
                ),
                _detailRow(label: '念诵遍数', value: '${record.chantCount} 部'),
                _detailRow(label: '来源', value: record.sourceLabel),
                if (record.startTime != null)
                  _detailRow(label: '开始', value: record.startTime!.toString()),
                if (record.endTime != null)
                  _detailRow(label: '结束', value: record.endTime!.toString()),
                if (record.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.notes!,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSourceChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_done_outlined,
              color: Color(0xFFE74C3C),
              size: 52,
            ),
            const SizedBox(height: 16),
            const Text(
              '登录后记录修行',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '修行记录会保存到云端，换设备后也能继续查看。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0 分钟';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return remain == 0 ? '$hours 小时' : '$hours 小时 $remain 分钟';
  }
}
