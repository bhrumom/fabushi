import 'package:flutter/material.dart';
import '../widgets/earth_globe_widget.dart';

class EarthGlobeDemoScreen extends StatefulWidget {
  const EarthGlobeDemoScreen({super.key});

  @override
  State<EarthGlobeDemoScreen> createState() => _EarthGlobeDemoScreenState();
}

class _EarthGlobeDemoScreenState extends State<EarthGlobeDemoScreen> {
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();
  bool _isSending = false;
  int _sentCount = 0;
  String _currentCity = '';

  // 全球主要城市坐标
  final List<Map<String, dynamic>> _worldCities = [
    // 亚洲
    {'name': '北京', 'lat': 39.9042, 'lng': 116.4074, 'continent': '亚洲', 'color': Colors.red},
    {'name': '东京', 'lat': 35.6762, 'lng': 139.6503, 'continent': '亚洲', 'color': Colors.pink},
    {'name': '首尔', 'lat': 37.5665, 'lng': 126.9780, 'continent': '亚洲', 'color': Colors.purple},
    {'name': '新加坡', 'lat': 1.3521, 'lng': 103.8198, 'continent': '亚洲', 'color': Colors.deepPurple},
    {'name': '新德里', 'lat': 28.6139, 'lng': 77.2090, 'continent': '亚洲', 'color': Colors.orange},
    
    // 欧洲
    {'name': '伦敦', 'lat': 51.5074, 'lng': -0.1278, 'continent': '欧洲', 'color': Colors.blue},
    {'name': '巴黎', 'lat': 48.8566, 'lng': 2.3522, 'continent': '欧洲', 'color': Colors.indigo},
    {'name': '柏林', 'lat': 52.5200, 'lng': 13.4050, 'continent': '欧洲', 'color': Colors.blueGrey},
    {'name': '莫斯科', 'lat': 55.7558, 'lng': 37.6173, 'continent': '欧洲', 'color': Colors.cyan},
    
    // 美洲
    {'name': '纽约', 'lat': 40.7128, 'lng': -74.0060, 'continent': '美洲', 'color': Colors.teal},
    {'name': '旧金山', 'lat': 37.7749, 'lng': -122.4194, 'continent': '美洲', 'color': Colors.cyan},
    {'name': '多伦多', 'lat': 43.6532, 'lng': -79.3832, 'continent': '美洲', 'color': Colors.lightBlue},
    {'name': '圣保罗', 'lat': -23.5505, 'lng': -46.6333, 'continent': '美洲', 'color': Colors.green},
    
    // 大洋洲
    {'name': '悉尼', 'lat': -33.8688, 'lng': 151.2093, 'continent': '大洋洲', 'color': Colors.lime},
    
    // 非洲
    {'name': '开普敦', 'lat': -33.9249, 'lng': 18.4241, 'continent': '非洲', 'color': Colors.amber},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地球背景
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0a0a0a),
                  const Color(0xFF1a1a2e),
                  const Color(0xFF0a0a0a),
                ],
              ),
            ),
            child: Center(
              child: EarthGlobeWidget(key: _globeKey),
            ),
          ),
          
          // 标题
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
                ),
                child: const Text(
                  '🌍 全球法布施 - 实时传输轨迹',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          
          // 状态信息
          if (_isSending)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.black.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '正在发送到: $_currentCity',
                        style: const TextStyle(
                          color: Colors.cyan,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _sentCount / _worldCities.length,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_sentCount / ${_worldCities.length} 个城市',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // 控制面板
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '选择发送模式',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendToAll,
                            icon: const Icon(Icons.public),
                            label: const Text('全球发送'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : () => _sendByContinent('亚洲'),
                            icon: const Icon(Icons.location_on),
                            label: const Text('亚洲'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : () => _sendByContinent('欧洲'),
                            icon: const Icon(Icons.location_city),
                            label: const Text('欧洲'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : () => _sendByContinent('美洲'),
                            icon: const Icon(Icons.flag),
                            label: const Text('美洲'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('清除轨迹'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToAll() async {
    setState(() {
      _isSending = true;
      _sentCount = 0;
    });

    _globeKey.currentState?.clearBeams();

    const originLat = 39.9042; // 北京
    const originLng = 116.4074;

    for (var i = 0; i < _worldCities.length; i++) {
      final city = _worldCities[i];
      
      setState(() {
        _currentCity = city['name'];
        _sentCount = i + 1;
      });

      _globeKey.currentState?.addTransferBeam(
        originLat, originLng,
        city['lat'], city['lng'],
        color: city['color'],
      );

      await Future.delayed(const Duration(milliseconds: 250));
    }

    setState(() {
      _isSending = false;
      _currentCity = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ 已成功发送到全球 ${_worldCities.length} 个城市！'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sendByContinent(String continent) async {
    final cities = _worldCities.where((c) => c['continent'] == continent).toList();
    
    setState(() {
      _isSending = true;
      _sentCount = 0;
    });

    _globeKey.currentState?.clearBeams();

    const originLat = 39.9042;
    const originLng = 116.4074;

    for (var i = 0; i < cities.length; i++) {
      final city = cities[i];
      
      setState(() {
        _currentCity = city['name'];
        _sentCount = i + 1;
      });

      _globeKey.currentState?.addTransferBeam(
        originLat, originLng,
        city['lat'], city['lng'],
        color: city['color'],
      );

      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _isSending = false;
      _currentCity = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ 已成功发送到$continent ${cities.length} 个城市！'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearAll() {
    _globeKey.currentState?.clearBeams();
    setState(() {
      _sentCount = 0;
      _currentCity = '';
    });
  }
}
