import 'package:flutter/material.dart';

/// 传输统计显示组件
///
/// 显示文件传输的统计信息，如已发送文件数、已发送数据量等。
class TransferStatsDisplay extends StatelessWidget {
  /// 已发送文件数
  final int sentCount;

  /// 已发送数据量（MB）
  final double dataSentInMB;

  /// 是否显示标题
  final bool showTitle;

  /// 构造函数
  const TransferStatsDisplay({
    Key? key,
    required this.sentCount,
    required this.dataSentInMB,
    this.showTitle = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Text('传输统计', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16.0),
            ],
            _buildStatRow(context, '已发送节点数:', '$sentCount'),
            const SizedBox(height: 8.0),
            _buildStatRow(
              context,
              '已发送数据:',
              '${dataSentInMB.toStringAsFixed(2)} MB',
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计行
  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8.0),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
