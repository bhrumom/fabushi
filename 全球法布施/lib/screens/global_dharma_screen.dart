import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/file_transfer_model.dart';
import '../services/real_global_send_service.dart';
import '../config/country_servers.dart';

/// 全球法布施详细界面
/// 显示国家列表和实时发送状态
class GlobalDharmaScreen extends StatefulWidget {
  const GlobalDharmaScreen({Key? key}) : super(key: key);

  @override
  State<GlobalDharmaScreen> createState() => _GlobalDharmaScreenState();
}

class _GlobalDharmaScreenState extends State<GlobalDharmaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = context.read<FileTransferModel>();
      if (model.countryStatuses.isEmpty) {
        model.initializeCountryStatuses(GLOBAL_COUNTRY_SERVERS, COUNTRY_NAMES);
      }
    });
  }

  void _parseLogAndUpdateStatus(String logMessage) {
    final model = context.read<FileTransferModel>();
    
    if (logMessage.contains('发送到') && logMessage.contains('成功')) {
      final regex = RegExp(r'发送到\s+([^()]+)\s+\([^()]+\)\s+.*成功');
      final match = regex.firstMatch(logMessage);
      if (match != null) {
        final countryName = match.group(1)?.trim();
        model.updateCountryStatus(countryName, SendStatus.success);
      }
    } else if (logMessage.contains('发送到') && logMessage.contains('失败')) {
      final regex = RegExp(r'发送到\s+([^()]+)\s+\([^()]+\)\s+.*失败');
      final match = regex.firstMatch(logMessage);
      if (match != null) {
        final countryName = match.group(1)?.trim();
        model.updateCountryStatus(countryName, SendStatus.failed);
      }
    } else if (logMessage.contains('正在发送到')) {
      final regex = RegExp(r'正在发送到\s+([^()]+)\s+\([^()]+\)');
      final match = regex.firstMatch(logMessage);
      if (match != null) {
        final countryName = match.group(1)?.trim();
        model.updateCountryStatus(countryName, SendStatus.sending);
      }
    }
  }

  Future<void> _startGlobalDharma() async {
    final model = context.read<FileTransferModel>();
    if (!model.hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要发送的文件')),
      );
      return;
    }

    // 只在用户主动点击开始时重置状态
    for (int i = 0; i < model.countryStatuses.length; i++) {
      model.updateCountryStatus(model.countryStatuses[i].countryName, SendStatus.pending);
    }
    
    await model.startGlobalTransfer();
  }

  void _stopGlobalDharma() {
    final model = context.read<FileTransferModel>();
    model.stopTransfer();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FileTransferModel>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌍 全球法布施'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          if (model.isTransferring)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopGlobalDharma,
              tooltip: '停止发送',
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startGlobalDharma,
              tooltip: '开始发送',
            ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息卡片
          _buildStatsCard(model),
          
          // 当前日志
          if (model.currentLog.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model.currentLog,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // 国家列表
          Expanded(
            child: _buildCountryList(model),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: model.isTransferring ? _stopGlobalDharma : _startGlobalDharma,
        icon: Icon(model.isTransferring ? Icons.stop : Icons.play_arrow),
        label: Text(model.isTransferring ? '停止发送' : '开始法布施'),
        backgroundColor: model.isTransferring ? Colors.red : const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatsCard(FileTransferModel model) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_present, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '已选文件: ${model.selectedFiles.length} 个',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.public, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '目标国家: ${model.countryStatuses.length} 个',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.send, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '已发送: ${model.globalSentCount} 个文件',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.data_usage, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  '数据量: ${model.globalDataSentMB.toStringAsFixed(2)} MB',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            if (model.isLooping) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.loop, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    '循环模式: 开启',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountryList(FileTransferModel model) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.list, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '国家发送状态 (${model.getSuccessCount()}/${model.countryStatuses.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: model.countryStatuses.length,
            itemBuilder: (context, index) {
              final status = model.countryStatuses[index];
              return _buildCountryStatusItem(status);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCountryStatusItem(CountrySendStatus status) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildStatusIcon(status.status),
        title: Text(
          '${status.countryName} (${status.countryCode})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('服务器数量: ${status.serverCount}'),
        trailing: _buildStatusText(status.status),
      ),
    );
  }

  Widget _buildStatusIcon(SendStatus status) {
    switch (status) {
      case SendStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green);
      case SendStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case SendStatus.sending:
        return const Icon(Icons.upload, color: Colors.orange);
      case SendStatus.pending:
        return const Icon(Icons.schedule, color: Colors.grey);
    }
  }

  Widget _buildStatusText(SendStatus status) {
    switch (status) {
      case SendStatus.success:
        return const Text('成功', style: TextStyle(color: Colors.green));
      case SendStatus.failed:
        return const Text('失败', style: TextStyle(color: Colors.red));
      case SendStatus.sending:
        return const Text('发送中', style: TextStyle(color: Colors.orange));
      case SendStatus.pending:
        return const Text('等待中', style: TextStyle(color: Colors.grey));
    }
  }
}