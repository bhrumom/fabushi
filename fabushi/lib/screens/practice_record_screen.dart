import 'package:flutter/material.dart';
import '../widgets/practice_stats_card.dart';
import '../widgets/practice_dialogs.dart';

/// 修行记录页面 - 完整的修行统计展示
class PracticeRecordScreen extends StatelessWidget {
  const PracticeRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          '修行记录',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PracticeStatsCard(
          onTapRecord: () {
            showDialog(
              context: context,
              builder: (context) => const AddPracticeRecordDialog(),
            );
          },
          onTapHistory: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('修行记录功能完善中')),
            );
          },
          onTapDedication: () {
            showDialog(
              context: context,
              builder: (context) => const SetGoalDialog(),
            );
          },
          onTapSettings: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('功课设置功能完善中')),
            );
          },
        ),
      ),
    );
  }
}
