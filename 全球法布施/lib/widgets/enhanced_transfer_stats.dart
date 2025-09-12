import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 增强版传输统计显示组件
/// 增强版传输统计显示组件
/// 
/// 显示所有传输模式的统计信息，包括全球发送和WiFi广播
class EnhancedTransferStats extends StatelessWidget {
  const EnhancedTransferStats({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<FileTransferModel>(
      builder: (context, model, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '法布施统计',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16.0),
                
                // 法布施统计
                _buildModeHeader(context, '法布施统计', Icons.analytics),
                const SizedBox(height: 8.0),
                _buildStatRow(context, '已传播节点数:', '${model.globalSentCount}'),
                const SizedBox(height: 4.0),
                _buildStatRow(context, '已传播数据:', '${model.globalDataSentMB.toStringAsFixed(2)} MB'),
                
                // Web环境提示
                if (kIsWeb) ...[
                  const Divider(),
                  const SizedBox(height: 8.0),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            'Web环境下，法布施内容通过真实网络请求发送到全球，无需接收设备',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
  
  /// 构建模式标题
  Widget _buildModeHeader(
    BuildContext context, 
    String title, 
    IconData icon, 
    {bool isHighlighted = false}
  ) {
    return Row(
      children: [
        Icon(
          icon, 
          color: isHighlighted ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
          size: 20,
        ),
        const SizedBox(width: 8.0),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? Theme.of(context).colorScheme.primary : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
  
  /// 构建统计行
  Widget _buildStatRow(
    BuildContext context, 
    String label, 
    String value, 
    {bool isHighlighted = false, bool isBold = false}
  ) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isHighlighted ? Theme.of(context).colorScheme.primary.withOpacity(0.8) : null,
          ),
        ),
        const SizedBox(width: 8.0),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted 
                ? Theme.of(context).colorScheme.primary 
                : isBold 
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).primaryColor,
            fontWeight: isBold || isHighlighted ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}