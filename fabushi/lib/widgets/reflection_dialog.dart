import 'package:flutter/material.dart';

/// 修行心得填写弹窗
///
/// 修行结束后显示，用户可填写心得并保存到对应的云端修行记录。
class ReflectionDialog extends StatefulWidget {
  final Duration duration;
  final int chantCount;
  final String sutraTitle;
  final String filePath;
  final VoidCallback? onCompleted;

  const ReflectionDialog({
    super.key,
    required this.duration,
    required this.chantCount,
    required this.sutraTitle,
    required this.filePath,
    this.onCompleted,
  });

  @override
  State<ReflectionDialog> createState() => _ReflectionDialogState();
}

class _ReflectionDialogState extends State<ReflectionDialog> {
  final TextEditingController _contentController = TextEditingController();
  bool _isSubmitting = false;

  String get _formattedDuration {
    final minutes = widget.duration.inMinutes;
    final seconds = widget.duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _submitReflection() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写修行心得'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (mounted) {
        Navigator.pop(context, content);
        widget.onCompleted?.call();
      }
    } catch (e) {
      debugPrint('保存心得失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败，请稍后重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Text('🙏', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Text('功德圆满', style: TextStyle(color: Colors.white, fontSize: 22)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 修行统计
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD4AF37).withOpacity(0.2),
                    const Color(0xFFD4AF37).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildStatRow('📖 功课', widget.sutraTitle),
                  const Divider(color: Colors.white12, height: 20),
                  _buildStatRow('⏱️ 修行时长', _formattedDuration),
                  const Divider(color: Colors.white12, height: 20),
                  _buildStatRow('📿 念诵遍数', '${widget.chantCount}'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 心得输入
            const Text(
              '记录修行心得（可选）',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '今日修行有何感悟？写入自己的修行记录...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              '心得会随本次修行记录同步到云端，仅自己可见',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onCompleted?.call();
                },
          child: const Text('跳过', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReflection,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            disabledBackgroundColor: Colors.white24,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('保存心得', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// 显示修行心得填写弹窗
Future<String?> showReflectionDialog(
  BuildContext context, {
  required Duration duration,
  required int chantCount,
  required String sutraTitle,
  required String filePath,
  VoidCallback? onCompleted,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ReflectionDialog(
      duration: duration,
      chantCount: chantCount,
      sutraTitle: sutraTitle,
      filePath: filePath,
      onCompleted: onCompleted,
    ),
  );
}
