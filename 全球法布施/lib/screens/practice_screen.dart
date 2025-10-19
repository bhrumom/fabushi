import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/practice_model.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final List<String> sutras = ['心经', '大悲咒', '楞严咒', '往生咒', '准提咒'];
  String? selectedSutra;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修习室')),
      body: Consumer<PracticeModel>(
        builder: (context, model, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (model.currentSession == null) ...[
                  _buildSutraSelector(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: selectedSutra != null ? () => _startPractice(model) : null,
                    child: const Text('开始修习'),
                  ),
                ] else ...[
                  _buildActiveSession(model),
                ],
                const SizedBox(height: 40),
                _buildStats(model),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSutraSelector() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: '选择经文'),
      value: selectedSutra,
      items: sutras.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => selectedSutra = v),
    );
  }

  Widget _buildActiveSession(PracticeModel model) {
    final session = model.currentSession!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(session.sutraName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            Text('计数: ${session.count}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, _) {
                final duration = session.duration;
                return Text('${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}');
              },
            ),
            const SizedBox(height: 20),
            const Text('按音量+键增加计数', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => model.endSession(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('结束修习'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(PracticeModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('累计统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('总计数: ${model.totalCount}'),
            Text('总时长: ${model.totalDuration.inMinutes} 分钟'),
          ],
        ),
      ),
    );
  }

  void _startPractice(PracticeModel model) {
    model.startSession(selectedSutra!);
    // 监听音量键
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      context.read<PracticeModel>().incrementCount();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    super.dispose();
  }
}
