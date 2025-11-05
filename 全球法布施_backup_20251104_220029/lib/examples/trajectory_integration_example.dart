/// 3D地球优美轨迹集成示例

import 'package:flutter/material.dart';
import '../widgets/earth_globe_widget.dart';
import '../widgets/enhanced_earth_globe_widget.dart';

// 示例1：基础集成
class BasicTrajectoryExample extends StatefulWidget {
  const BasicTrajectoryExample({super.key});

  @override
  State<BasicTrajectoryExample> createState() => _BasicTrajectoryExampleState();
}

class _BasicTrajectoryExampleState extends State<BasicTrajectoryExample> {
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();

  void _sendBeam() {
    _globeKey.currentState?.addTransferBeamByCountryCode(
      'CN', 'US',
      color: Colors.cyan,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(child: EarthGlobeWidget(key: _globeKey)),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _sendBeam,
              child: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}

// 示例2：增强版
class EnhancedTrajectoryExample extends StatefulWidget {
  const EnhancedTrajectoryExample({super.key});

  @override
  State<EnhancedTrajectoryExample> createState() => _EnhancedTrajectoryExampleState();
}

class _EnhancedTrajectoryExampleState extends State<EnhancedTrajectoryExample> {
  final GlobalKey<EnhancedEarthGlobeWidgetState> _globeKey = GlobalKey();

  void _sendBeam() {
    _globeKey.currentState?.addBeautifulTrajectory(
      fromLat: 39.9042,
      fromLng: 116.4074,
      toLat: 40.7128,
      toLng: -74.0060,
      color: Colors.cyan,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: EnhancedEarthGlobeWidget(key: _globeKey)),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendBeam,
        child: const Icon(Icons.rocket_launch),
      ),
    );
  }
}

// 示例3：文件传输集成
class FileTransferExample extends StatefulWidget {
  const FileTransferExample({super.key});

  @override
  State<FileTransferExample> createState() => _FileTransferExampleState();
}

class _FileTransferExampleState extends State<FileTransferExample> {
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();
  bool _isTransferring = false;

  Future<void> _startTransfer() async {
    setState(() => _isTransferring = true);

    final countries = ['US', 'GB', 'JP', 'DE', 'FR'];
    
    for (var country in countries) {
      if (!mounted) break;
      
      _globeKey.currentState?.addTransferBeamByCountryCode(
        'CN', country,
        color: Colors.green,
        duration: const Duration(seconds: 2),
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() => _isTransferring = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(child: EarthGlobeWidget(key: _globeKey)),
          ),
          Expanded(
            child: Center(
              child: _isTransferring
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _startTransfer,
                      child: const Text('开始传输'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
