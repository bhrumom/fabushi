import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../widgets/earth_globe_widget.dart';
import '../screens/asset_screen.dart';

class GlobeHomeScreen extends StatefulWidget {
  const GlobeHomeScreen({super.key});

  @override
  State<GlobeHomeScreen> createState() => _GlobeHomeScreenState();
}

class _GlobeHomeScreenState extends State<GlobeHomeScreen> {
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: const Color(0xFF0a0a0a),
            child: EarthGlobeWidget(key: _globeKey),
          ),
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: _buildStatusBar(),
          ),
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: _buildControlPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Consumer<FileTransferModel>(
      builder: (context, model, _) {
        if (!model.isTransferring) return const SizedBox.shrink();
        
        return Card(
          color: Colors.black.withOpacity(0.7),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '正在向全球发送经文...',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: model.progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(model.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    return Consumer<FileTransferModel>(
      builder: (context, model, _) {
        return Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.selectedFile?.name ?? '未选择经文',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectFile(context),
                        icon: const Icon(Icons.menu_book),
                        label: const Text('选择经文'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: model.selectedFile != null && !model.isTransferring
                            ? () => _startSending(model)
                            : null,
                        icon: const Icon(Icons.send),
                        label: const Text('开始发送'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectFile(BuildContext context) async {
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await model.selectBuiltInAssets(context);
  }

  void _startSending(FileTransferModel model) async {
    _globeKey.currentState?.clearBeams();
    
    // 添加传输光束动画
    final destinations = [
      {'lat': 37.7749, 'lng': -122.4194},
      {'lat': 51.5074, 'lng': -0.1278},
      {'lat': 35.6762, 'lng': 139.6503},
      {'lat': -33.8688, 'lng': 151.2093},
      {'lat': 28.6139, 'lng': 77.2090},
      {'lat': -23.5505, 'lng': -46.6333},
    ];
    
    for (var dest in destinations) {
      _globeKey.currentState?.addTransferBeam(
        39.9042, 116.4074,
        dest['lat']!, dest['lng']!,
      );
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // 开始真实的全球发送
    await model.startGlobalTransfer();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('经文已成功发送到全球！'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
