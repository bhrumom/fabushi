import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';

class WifiBroadcastVisualization extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FileTransferModel>(context);
    final bool isActive = model.isTransferring && model.isWifiSendEnabled && model.hasFiles;

    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本地WiFi发送可视化', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            // WiFi状态指示器
            Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: model.isWifiSendEnabled && model.hasFiles ? Colors.blue : Colors.grey,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  model.isWifiSendEnabled && model.hasFiles ? 'WiFi发送已启用' : 'WiFi发送未启用',
                  style: TextStyle(
                    color: model.isWifiSendEnabled && model.hasFiles ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // 发送进度信息
            if (model.dataSentInMB > 0 && model.isWifiSendEnabled && model.hasFiles)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已发送: ${model.dataSentInMB.toStringAsFixed(2)} MB'),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: model.hasFiles 
                      ? model.dataSentInMB / (model.selectedFiles.first.size / 1024 / 1024) 
                      : 0,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0 MB'),
                      Text('${(model.selectedFiles.first.size / 1024 / 1024).toStringAsFixed(2)} MB'),
                    ],
                  ),
                ],
              ),
            // 网络状态指示器
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.wifi_tethering,
                  color: isActive ? Colors.green : Colors.grey,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  isActive ? '正在发送...' : '等待发送',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}