import 'package:flutter/material.dart';

class NoConnectionStatusWidget extends StatelessWidget {
  final bool isRunning;
  final int sentCount;
  final double dataSentInMB;
  final String selectedCountry;
  final bool isLoopMode;
  final Map<String, dynamic>? targetInfo;
  final Map<String, dynamic>? connectionTestResults;

  const NoConnectionStatusWidget({
    Key? key,
    required this.isRunning,
    required this.sentCount,
    required this.dataSentInMB,
    required this.selectedCountry,
    required this.isLoopMode,
    this.targetInfo,
    this.connectionTestResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📡 发送状态',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isRunning ? Icons.radio_button_checked : Icons.check_circle,
                  color: isRunning ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(isRunning ? '正在发送...' : '发送完成'),
              ],
            ),
            const SizedBox(height: 8),
            Text('已发送: $sentCount 个文件'),
            Text('数据量: ${dataSentInMB.toStringAsFixed(2)} MB'),
            Text('目标区域: $selectedCountry'),
            if (isLoopMode) const Text('模式: 循环发送'),
          ],
        ),
      ),
    );
  }
}