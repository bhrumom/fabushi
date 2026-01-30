import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';

class FileSelectionCard extends StatelessWidget {
  final VoidCallback onSelectFiles;
  final VoidCallback onSelectAssets;

  const FileSelectionCard({Key? key, required this.onSelectFiles, required this.onSelectAssets})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<FileTransferModel>(
          builder: (context, model, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已选文件', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150, // Provide a fixed height or use other constraints
                  child: model.hasFiles
                      ? ListView.builder(
                          itemCount: model.selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = model.selectedFiles[index];
                            return ListTile(
                              leading: Icon(_getIconForFileType(model.getFileType(file.name))),
                              title: Text(file.name),
                              subtitle: Text(model.getFileSizeString(file.size)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => model.removeFile(file),
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '请选择要发送的文件',
                              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_to_drive),
                          label: const Text('从设备选择'),
                          onPressed: onSelectFiles,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.collections_bookmark_outlined),
                          label: const Text('内置素材'),
                          onPressed: onSelectAssets,
                        ),
                      ],
                    ),
                    if (model.hasFiles)
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, color: Colors.red),
                        label: const Text('清空', style: TextStyle(color: Colors.red)),
                        onPressed: () => model.clearFiles(),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _getIconForFileType(String fileType) {
    switch (fileType) {
      case '图片':
        return Icons.image;
      case '文档':
        return Icons.article;
      case '音频':
        return Icons.audiotrack;
      case '视频':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }
}
