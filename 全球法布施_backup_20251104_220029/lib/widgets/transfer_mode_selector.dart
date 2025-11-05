import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';

/// 传输模式选择器
/// 
/// 允许用户选择不同的传输模式，如全球发送和WiFi广播
class TransferModeSelector extends StatelessWidget {
  const TransferModeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<FileTransferModel>(
      builder: (context, model, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '法布施设置',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16.0),
                _buildLoopingSwitch(
                  context,
                  title: '循环法布施',
                  subtitle: '持续重复传播选定的法布施内容',
                  value: model.isLooping,
                  onChanged: (value) {
                    model.setLooping(value);
                  },
                ),
                const Divider(),
                _buildSpeedControl(context, model),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isHighlighted = false,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          color: isHighlighted ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: isHighlighted ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }

  Widget _buildLoopingSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.amber,
      ),
    );
  }

  Widget _buildSpeedControl(BuildContext context, FileTransferModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('发送速度: ${model.sendRateMB.toStringAsFixed(1)} MB/秒'),
        Slider(
          value: model.sendRateMB,
          min: 0.1,
          max: 5.0,
          divisions: 49,
          onChanged: (value) {
            model.setSendRateMB(value);
          },
        ),
      ],
    );
  }
}