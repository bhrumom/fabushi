import 'package:flutter/material.dart';
import '../services/meditation_session_manager.dart';

/// 必选功课底部弹窗
/// 
/// 首次进入禅室时显示，要求用户手动输入一门修行功课。
class PracticeSelectionSheet extends StatefulWidget {
  final VoidCallback? onSelected;
  final bool isDismissible; // 是否可以取消/关闭

  const PracticeSelectionSheet({
    super.key,
    this.onSelected,
    this.isDismissible = true, // 默认可关闭
  });

  @override
  State<PracticeSelectionSheet> createState() => _PracticeSelectionSheetState();
}

class _PracticeSelectionSheetState extends State<PracticeSelectionSheet> {
  final MeditationSessionManager _sessionManager = MeditationSessionManager();
  final TextEditingController _practiceController = TextEditingController();
  String _practiceTitle = '';

  @override
  void initState() {
    super.initState();
    _practiceController.addListener(() {
      final value = _practiceController.text.trim();
      if (value != _practiceTitle) {
        setState(() => _practiceTitle = value);
      }
    });
  }

  @override
  void dispose() {
    _practiceController.dispose();
    super.dispose();
  }

  Future<void> _confirmSelection() async {
    final title = _practiceTitle.trim();
    if (title.isEmpty) return;
    
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '确认选择功课',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '您填写了：$title',
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '一旦确认，功课将锁定，无法更改。\n请慎重选择！',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: const Text('确认锁定', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 锁定功课
      final success = await _sessionManager.selectAndLockPractice(
        title,
        'manual:${Uri.encodeComponent(title)}',
      );
      
      if (success && mounted) {
        Navigator.pop(context);
        widget.onSelected?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选定功课：$title'),
            backgroundColor: const Color(0xFFD4AF37),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 手柄
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 标题和关闭按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // 占位
                const Text(
                  '🙏 填写主修功课',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.isDismissible)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  )
                else
                  const SizedBox(width: 40), // 保持布局对称
              ],
            ),
          ),
          
          // 重要警告提醒
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.2),
                  Colors.orange.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '重要提醒',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '一旦确认，主修功课将永久锁定，无法修改！',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Text(
            '请手动输入您一门深入的主修功课',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          
          // 主修功课输入
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: TextField(
              controller: _practiceController,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：阿弥陀佛圣号、地藏经、准提咒',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.edit_note, color: Colors.white54),
                suffixIcon: _practiceTitle.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: _practiceController.clear,
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          const Spacer(),
          
          // 底部确认按钮
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _practiceTitle.isNotEmpty ? _confirmSelection : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _practiceTitle.isNotEmpty ? '确认锁定「$_practiceTitle」' : '请先填写主修功课',
                    style: TextStyle(
                      color: _practiceTitle.isNotEmpty ? Colors.black : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

/// 显示功课选择弹窗
/// 
/// [required] 为 true 时表示必选，弹窗不可取消
Future<void> showPracticeSelectionSheet(
  BuildContext context, {
  VoidCallback? onSelected,
  bool required = false, // 是否为必选模式（不可取消）
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: !required, // 必选时不可通过点击外部关闭
    enableDrag: !required, // 必选时不可通过下拉关闭
    backgroundColor: Colors.transparent,
    builder: (context) => PracticeSelectionSheet(
      onSelected: onSelected,
      isDismissible: !required,
    ),
  );
}
