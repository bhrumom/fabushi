import 'package:flutter/material.dart';
import '../services/content_report_service.dart';
import '../services/user_block_service.dart';

/// 举报和屏蔽弹窗
///
/// 用于举报不当内容和屏蔽用户
class ReportDialog extends StatefulWidget {
  final String contentId;
  final String? authorId;
  final String? authorName;
  final bool isAuthor;
  final VoidCallback? onActionCompleted;

  const ReportDialog({
    super.key,
    required this.contentId,
    this.authorId,
    this.authorName,
    this.isAuthor = false,
    this.onActionCompleted,
  });

  /// 显示举报/屏蔽选项底部弹窗
  static Future<void> show(
    BuildContext context, {
    required String contentId,
    String? authorId,
    String? authorName,
    bool isAuthor = false,
    VoidCallback? onActionCompleted,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReportDialog(
        contentId: contentId,
        authorId: authorId,
        authorName: authorName,
        isAuthor: isAuthor,
        onActionCompleted: onActionCompleted,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  bool _showReportReasons = false;
  bool _isSubmitting = false;
  ReportReason? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    final success = await ContentReportService().reportContent(
      contentId: widget.contentId,
      reason: _selectedReason!,
      description: _descriptionController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();

      widget.onActionCompleted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '举报已提交，我们将在24小时内处理' : '举报提交失败，请稍后重试'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _blockUser() async {
    if (widget.authorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F36),
        title: const Text('确认屏蔽', style: TextStyle(color: Colors.white)),
        content: Text(
          '屏蔽后，${widget.authorName ?? '该用户'}的内容将从您的信息流中移除。\n\n同时将通知开发者审核该用户的内容。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认屏蔽', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await UserBlockService().blockUser(widget.authorId!, reason: '用户主动屏蔽');

    if (mounted) {
      Navigator.of(context).pop();

      widget.onActionCompleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已屏蔽${widget.authorName ?? '该用户'}'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '撤销',
            textColor: Colors.white,
            onPressed: () async {
              await UserBlockService().unblockUser(widget.authorId!);
            },
          ),
        ),
      );
    }
  }

  Future<void> _deleteContent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F36),
        title: const Text('确认删除', style: TextStyle(color: Colors.white)),
        content: const Text(
          '删除后无法恢复，确定要删除此作品吗？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // TODO: 实现真实的内容删除API调用
    if (mounted) {
      Navigator.of(context).pop();
      widget.onActionCompleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已请求删除作品'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F36),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: _showReportReasons ? _buildReportForm() : _buildMainMenu(),
      ),
    );
  }

  /// 主菜单：举报/屏蔽选项
  Widget _buildMainMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 拖动手柄
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '更多操作',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        if (widget.isAuthor)
          _buildMenuItem(
            icon: Icons.delete_forever,
            label: '删除作品',
            subtitle: '永久删除此内容',
            color: Colors.red,
            onTap: _deleteContent,
          )
        else ...[
          // 举报内容
          _buildMenuItem(
            icon: Icons.flag_outlined,
            label: '举报内容',
            subtitle: '举报不当或违规内容',
            color: Colors.orange,
            onTap: () => setState(() => _showReportReasons = true),
          ),

          // 屏蔽用户
          if (widget.authorId != null)
            _buildMenuItem(
              icon: Icons.block,
              label: '屏蔽${widget.authorName ?? '该用户'}',
              subtitle: '屏蔽后不再看到此用户的内容',
              color: Colors.red,
              onTap: _blockUser,
            ),
        ],

        const SizedBox(height: 8),

        // 取消
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '取消',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  /// 举报原因选择表单
  Widget _buildReportForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动手柄
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // 标题栏
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => setState(() => _showReportReasons = false),
              ),
              const Text(
                '举报原因',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 举报原因列表
          ...ReportReason.values.map((reason) {
            final isSelected = _selectedReason == reason;
            return InkWell(
              onTap: () => setState(() => _selectedReason = reason),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? const Color(0xFF667EEA)
                          : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      reason.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // 详细描述
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '请描述具体问题（可选）',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF667EEA)),
                ),
              ),
            ),
          ),

          // 提交按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReason != null && !_isSubmitting
                    ? _submitReport
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white30,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    : const Text(
                        '提交举报',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
