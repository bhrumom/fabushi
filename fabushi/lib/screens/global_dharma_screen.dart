import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../core/constants/country_servers.dart';
import 'search_screen.dart';

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
      if (model.countryStatuses.isEmpty && !model.isTransferring) {
        model.initializeCountryStatuses(GLOBAL_COUNTRY_SERVERS, COUNTRY_NAMES);
      }
    });
  }

  Future<void> _startGlobalDharma() async {
    final model = context.read<FileTransferModel>();
    if (!model.hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在首页选择链接、文本、本机文件或禅室佛像素材。')),
      );
      return;
    }

    await model.startGlobalTransfer();

    if (!mounted || model.isTransferring || model.isPreparingSend) {
      return;
    }

    if (model.globalSentCount == 0 && model.currentLog.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(model.currentLog)));
    }
  }

  void _stopGlobalDharma() {
    context.read<FileTransferModel>().stopTransfer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌍 大乘'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            ),
            tooltip: '搜索经文',
          ),
          Consumer<FileTransferModel>(
            builder: (context, model, child) => model.isPreparingSend
                ? IconButton(
                    icon: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: null,
                    tooltip: '正在准备发送',
                  )
                : model.isTransferring
                ? IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: _stopGlobalDharma,
                    tooltip: '停止发送',
                  )
                : IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _startGlobalDharma,
                    tooltip: '开始发送',
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Selector<FileTransferModel, List<dynamic>>(
            selector: (_, m) => [
              m.selectedFiles.length,
              m.countryStatuses.length,
              m.globalSentCount,
              m.globalDataSentMB,
              m.isLooping,
            ],
            builder: (context, data, child) => _buildStatsCard(
              data[0] as int,
              data[1] as int,
              data[2] as int,
              data[3] as double,
              data[4] as bool,
            ),
          ),
          Selector<FileTransferModel, String>(
            selector: (_, m) => m.currentLog,
            builder: (context, log, child) => log.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Selector<FileTransferModel, String>(
            selector: (_, m) => m.currentSendingScripture,
            builder: (context, scripture, child) => scripture.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book, color: Color(0xFF667eea)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '当前内容：$scripture',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(child: _buildCountryList()),
        ],
      ),
      floatingActionButton: Consumer<FileTransferModel>(
        builder: (context, model, child) => FloatingActionButton.extended(
          onPressed: model.isPreparingSend
              ? null
              : model.isTransferring
              ? _stopGlobalDharma
              : _startGlobalDharma,
          icon: model.isPreparingSend
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(model.isTransferring ? Icons.stop : Icons.play_arrow),
          label: Text(
            model.isPreparingSend
                ? '准备发送中'
                : model.isTransferring
                ? '停止发送'
                : '开始法布施',
          ),
          backgroundColor: model.isTransferring
              ? Colors.red
              : const Color(0xFF667eea),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    int filesCount,
    int countriesCount,
    int sentCount,
    double dataMB,
    bool isLooping,
  ) {
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
                  '当前缓存: $filesCount 部',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.public, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '目标国家: $countriesCount 个',
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
                  '已发送: $sentCount 个国家',
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
                  '数据量: ${dataMB.toStringAsFixed(2)} MB',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            if (isLooping) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.loop, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('循环模式: 开启', style: TextStyle(fontSize: 16)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountryList() {
    return Consumer<FileTransferModel>(
      builder: (context, model, child) {
        final statuses = model.countryStatuses;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.list, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '国家发送状态 (${statuses.where((s) => s.status == SendStatus.success).length}/${statuses.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final status = statuses[index];
                  return _buildCountryStatusItem(status);
                },
              ),
            ),
          ],
        );
      },
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
