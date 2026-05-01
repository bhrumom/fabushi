import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// 传输控制面板
///
/// 提供文件选择和传输控制功能的组件。
class TransferControlPanel extends StatelessWidget {
  /// 选择文件的回调
  final VoidCallback onPickFiles;

  /// 发送文件的回调
  final VoidCallback onSendFiles;

  /// 已选择的文件列表
  final List<PlatformFile> selectedFiles;

  /// 是否正在发送
  final bool isSending;

  /// 是否禁用发送按钮
  final bool disableSend;

  /// 构造函数
  const TransferControlPanel({
    Key? key,
    required this.onPickFiles,
    required this.onSendFiles,
    required this.selectedFiles,
    this.isSending = false,
    this.disableSend = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('传输控制', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16.0),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_upload),
                  label: const Text('选择文件'),
                  onPressed: isSending ? null : onPickFiles,
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Text(
                    selectedFiles.isEmpty
                        ? '未选择文件'
                        : '已选择 ${selectedFiles.length} 个文件',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (selectedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: selectedFiles
                      .map(
                        (file) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${file.name} (${_formatFileSize(file.size)})',
                            style: const TextStyle(fontSize: 12.0),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('发送文件'),
              onPressed: (selectedFiles.isEmpty || isSending || disableSend)
                  ? null
                  : onSendFiles,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48.0),
              ),
            ),
            if (isSending)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('正在发送...'),
                    SizedBox(height: 8.0),
                    LinearProgressIndicator(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
