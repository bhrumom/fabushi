import 'package:flutter/material.dart';
import '../services/practice_stats_service.dart';

/// 补录功课对话框
class AddPracticeRecordDialog extends StatefulWidget {
  final String? initialSutra;
  final PracticeRecord? initialRecord;

  const AddPracticeRecordDialog({
    super.key,
    this.initialSutra,
    this.initialRecord,
  });

  @override
  State<AddPracticeRecordDialog> createState() =>
      _AddPracticeRecordDialogState();
}

class _AddPracticeRecordDialogState extends State<AddPracticeRecordDialog> {
  final _sutraController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _durationController = TextEditingController(text: '30');
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  bool get _isEditing => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    final initialRecord = widget.initialRecord;
    if (initialRecord != null) {
      _sutraController.text = initialRecord.sutraName;
      _countController.text = initialRecord.chantCount.toString();
      _durationController.text = initialRecord.duration.toString();
      _notesController.text = initialRecord.notes ?? '';
      final parsedDate = DateTime.tryParse(initialRecord.recordDate);
      if (parsedDate != null) {
        _selectedDate = parsedDate;
      }
      if (initialRecord.localTime?.isNotEmpty == true) {
        final parts = initialRecord.localTime!.split(':');
        if (parts.length == 2) {
          _selectedTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? _selectedTime.hour,
            minute: int.tryParse(parts[1]) ?? _selectedTime.minute,
          );
        }
      }
    } else if (widget.initialSutra != null) {
      _sutraController.text = widget.initialSutra!;
    }
  }

  @override
  void dispose() {
    _sutraController.dispose();
    _countController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE74C3C),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE74C3C),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    final sutra = _sutraController.text.trim();
    final count = int.tryParse(_countController.text) ?? 0;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final notes = _notesController.text.trim();

    if (sutra.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入功课名称')));
      return;
    }

    if (count <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的遍数')));
      return;
    }

    if (duration < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的修行时长')));
      return;
    }

    setState(() => _isLoading = true);

    final service = PracticeStatsService();
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final success = _isEditing
        ? await service.updateRecord(
            recordId: widget.initialRecord!.id,
            sutra: sutra,
            chantCount: count,
            duration: duration,
            recordDate: dateStr,
            localTime: timeStr,
            notes: notes.isEmpty ? null : notes,
            isManual: widget.initialRecord!.isManual,
            sutraSource: widget.initialRecord!.sutraSource,
            timezoneOffsetMinutes:
                widget.initialRecord!.timezoneOffsetMinutes,
            startTime: widget.initialRecord!.startTime,
            endTime: widget.initialRecord!.endTime,
          )
        : await service.addManualRecord(
            sutra: sutra,
            chantCount: count,
            duration: duration,
            recordDate: dateStr,
            localTime: timeStr,
            notes: notes.isEmpty ? null : notes,
          );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '修行记录已更新'
                : service.lastWriteQueued
                    ? '网络暂不可用，补录已加入云端待同步'
                    : '功课已补录到云端',
          ),
          backgroundColor: _isEditing
              ? Colors.green
              : service.lastWriteQueued
                  ? Colors.orange
                  : Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? '更新失败，请检查网络后重试' : '补录失败，请先登录并检查网络'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? '编辑记录' : '补录功课',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 功课名称
            TextField(
              controller: _sutraController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '功课名称',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: '如：金刚经、心经等',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 遍数
            TextField(
              controller: _countController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '遍数/部数',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 日期选择
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '日期: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '当地时间: ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(
                      Icons.access_time,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _durationController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '修行时长（分钟）',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 备注
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '备注（可选）',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? '保存修改' : '确认补录'),
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

/// 发愿回向对话框
class SetGoalDialog extends StatefulWidget {
  final String? initialSutra;

  const SetGoalDialog({super.key, this.initialSutra});

  @override
  State<SetGoalDialog> createState() => _SetGoalDialogState();
}

class _SetGoalDialogState extends State<SetGoalDialog> {
  final _sutraController = TextEditingController();
  final _targetController = TextEditingController();
  final _dedicationController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSutra != null) {
      _sutraController.text = widget.initialSutra!;
    }
  }

  @override
  void dispose() {
    _sutraController.dispose();
    _targetController.dispose();
    _dedicationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sutra = _sutraController.text.trim();
    final target = int.tryParse(_targetController.text) ?? 0;
    final dedication = _dedicationController.text.trim();

    if (sutra.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入功课名称')));
      return;
    }

    if (target <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的目标数量')));
      return;
    }

    setState(() => _isLoading = true);

    final service = PracticeStatsService();
    final success = await service.setGoal(
      sutra: sutra,
      targetCount: target,
      dedication: dedication.isEmpty ? null : dedication,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发愿目标已设置'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '发愿回向',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 功课名称
            TextField(
              controller: _sutraController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '功课名称',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: '如：金刚经、心经等',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 目标数量
            TextField(
              controller: _targetController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '目标数量（部）',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: '如：10000',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 回向文
            TextField(
              controller: _dedicationController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '回向文（可选）',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: '愿以此功德，回向...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('确认发愿'),
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
