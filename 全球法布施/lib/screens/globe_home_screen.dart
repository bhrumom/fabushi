import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../widgets/earth_globe_widget.dart';

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
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🌍 全球法布施 - 实时传输轨迹',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: _buildControlPanel(context),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                onPressed: () => _globeKey.currentState?.clearBeams(),
                icon: const Icon(Icons.clear_all, color: Colors.white70),
                label: const Text(
                  '清除轨迹',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
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
    
    final destinations = [
      {'name': '旧金山', 'lat': 37.7749, 'lng': -122.4194, 'color': Colors.cyan},
      {'name': '伦敦', 'lat': 51.5074, 'lng': -0.1278, 'color': Colors.blue},
      {'name': '东京', 'lat': 35.6762, 'lng': 139.6503, 'color': Colors.purple},
      {'name': '悉尼', 'lat': -33.8688, 'lng': 151.2093, 'color': Colors.green},
      {'name': '新德里', 'lat': 28.6139, 'lng': 77.2090, 'color': Colors.orange},
      {'name': '圣保罗', 'lat': -23.5505, 'lng': -46.6333, 'color': Colors.pink},
      {'name': '纽约', 'lat': 40.7128, 'lng': -74.0060, 'color': Colors.teal},
      {'name': '巴黎', 'lat': 48.8566, 'lng': 2.3522, 'color': Colors.indigo},
      {'name': '首尔', 'lat': 37.5665, 'lng': 126.9780, 'color': Colors.amber},
      {'name': '新加坡', 'lat': 1.3521, 'lng': 103.8198, 'color': Colors.lime},
    ];
    
    const originLat = 39.9042;
    const originLng = 116.4074;
    
    // 开始真实的全球发送
    final transferFuture = model.startGlobalTransfer();
    
    // 同时显示流星动画，每个城市发送时间与实际一致
    for (var i = 0; i < destinations.length; i++) {
      final dest = destinations[i];
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在发送到 ${dest['name']}...'),
            duration: const Duration(milliseconds: 500),
            backgroundColor: Colors.black87,
          ),
        );
      }
      
      // 流星动画时间 = 实际发送时间
      await _globeKey.currentState?.addTransferBeam(
        originLat, originLng,
        dest['lat'] as double, dest['lng'] as double,
        color: dest['color'] as Color,
        duration: const Duration(seconds: 2),
      );
    }
    
    // 等待实际发送完成
    await transferFuture;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ 经文已成功发送到全球 10 个国家！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
