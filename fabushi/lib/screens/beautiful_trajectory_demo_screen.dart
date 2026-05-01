import 'package:flutter/material.dart';
import '../widgets/enhanced_earth_globe_widget.dart';
import '../services/country_coordinates_service.dart';
import 'dart:math' as math;

class BeautifulTrajectoryDemoScreen extends StatefulWidget {
  const BeautifulTrajectoryDemoScreen({super.key});

  @override
  State<BeautifulTrajectoryDemoScreen> createState() =>
      _BeautifulTrajectoryDemoScreenState();
}

class _BeautifulTrajectoryDemoScreenState
    extends State<BeautifulTrajectoryDemoScreen> {
  final GlobalKey<EnhancedEarthGlobeWidgetState> _globeKey = GlobalKey();
  final CountryCoordinatesService _coordService = CountryCoordinatesService();
  bool _isAutoPlaying = false;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _coordService.initialize();
  }

  void _sendRandomBeam() {
    final countries = _coordService.getAllCoordinates();
    if (countries.length < 2) return;

    final from = countries[_random.nextInt(countries.length)];
    final to = countries[_random.nextInt(countries.length)];

    _globeKey.currentState?.addBeautifulTrajectory(
      fromLat: from.latitude,
      fromLng: from.longitude,
      toLat: to.latitude,
      toLng: to.longitude,
    );
  }

  void _sendFromChina() {
    final china = _coordService.getByCountryCode('CN');
    final countries = _coordService.getAllCoordinates();
    if (china == null || countries.isEmpty) return;

    final to = countries[_random.nextInt(countries.length)];

    _globeKey.currentState?.addBeautifulTrajectory(
      fromLat: china.latitude,
      fromLng: china.longitude,
      toLat: to.latitude,
      toLng: to.longitude,
      color: Colors.red,
    );
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
    });

    if (_isAutoPlaying) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() async {
    while (_isAutoPlaying && mounted) {
      _sendFromChina();
      await Future.delayed(Duration(milliseconds: 800));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e27),
      appBar: AppBar(
        title: const Text('优美轨迹演示'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 3D地球
          Center(child: EnhancedEarthGlobeWidget(key: _globeKey)),

          // 控制面板
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildControlPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildButton(
                icon: Icons.shuffle,
                label: '随机发送',
                onPressed: _sendRandomBeam,
                color: Colors.blue,
              ),
              _buildButton(
                icon: Icons.flag,
                label: '从中国发送',
                onPressed: _sendFromChina,
                color: Colors.red,
              ),
              _buildButton(
                icon: _isAutoPlaying ? Icons.pause : Icons.play_arrow,
                label: _isAutoPlaying ? '停止' : '自动播放',
                onPressed: _toggleAutoPlay,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildButton(
            icon: Icons.clear,
            label: '清除所有',
            onPressed: () => _globeKey.currentState?.clearAll(),
            color: Colors.orange,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool fullWidth = false,
  }) {
    return Expanded(
      flex: fullWidth ? 1 : 0,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
