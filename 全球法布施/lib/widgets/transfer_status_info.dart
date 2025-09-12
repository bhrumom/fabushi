import 'package:flutter/material.dart';

/// 传输状态信息组件
/// 
/// 显示P2P网络和传输状态的信息组件。
class TransferStatusInfo extends StatelessWidget {
  /// 是否已初始化
  final bool isInitialized;
  
  /// 是否正在初始化
  final bool isInitializing;
  
  /// 已连接节点数
  final int connectedPeers;
  
  /// 已连接节点ID列表
  final List<String> connectedPeerIds;
  
  /// WebRTC是否支持
  final bool webrtcSupported;
  
  /// 蓝牙是否支持
  final bool bluetoothSupported;
  
  /// 构造函数
  const TransferStatusInfo({
    Key? key,
    required this.isInitialized,
    required this.isInitializing,
    required this.connectedPeers,
    required this.connectedPeerIds,
    required this.webrtcSupported,
    this.bluetoothSupported = false,
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
              'P2P网络状态',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16.0),
            _buildStatusRow(
              context,
              '初始化状态:',
              isInitialized ? '已初始化' : (isInitializing ? '初始化中...' : '未初始化'),
              isInitialized,
            ),
            _buildStatusRow(
              context,
              '已连接节点数:',
              '$connectedPeers',
              connectedPeers > 0,
            ),
            _buildStatusRow(
              context,
              'WebRTC支持:',
              webrtcSupported ? '支持' : '不支持',
              webrtcSupported,
            ),
            _buildStatusRow(
              context,
              'Web蓝牙支持:',
              bluetoothSupported ? '支持' : '不支持',
              bluetoothSupported,
            ),
            if (connectedPeerIds.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              const Text(
                '已连接节点:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4.0),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: connectedPeerIds
                      .map((peerId) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              peerId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12.0,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 构建状态行
  Widget _buildStatusRow(BuildContext context, String label, String value, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8.0),
          Text(
            value,
            style: TextStyle(
              color: isPositive ? Colors.green[700] : Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}