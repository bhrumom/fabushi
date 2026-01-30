import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';

class TransferControlBar extends StatelessWidget {
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;

  TransferControlBar({required this.onPauseResume, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FileTransferModel>(context);
    final status = model.status;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 暂停按钮（仅在传输中显示）
          if (status == TransferStatus.transferring)
            _buildControlButton(
              context: context,
              icon: Icons.pause,
              label: '暂停',
              color: Colors.orange,
              onPressed: onPauseResume,
            ),

          // 取消按钮
          if (status != TransferStatus.completed)
            _buildControlButton(
              context: context,
              icon: Icons.cancel,
              label: '取消',
              color: Colors.red,
              onPressed: onCancel,
            ),

          // 完成按钮
          if (status == TransferStatus.completed)
            _buildControlButton(
              context: context,
              icon: Icons.check_circle,
              label: '完成',
              color: Colors.green,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  // 构建控制按钮
  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      icon: Icon(icon, color: color, size: 24),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
        backgroundColor: color.withOpacity(0.1),
      ),
    );
  }
}
