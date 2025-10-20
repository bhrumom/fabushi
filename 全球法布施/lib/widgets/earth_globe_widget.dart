import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';

class EarthGlobeWidget extends StatefulWidget {
  const EarthGlobeWidget({super.key});

  @override
  State<EarthGlobeWidget> createState() => EarthGlobeWidgetState();
}

class EarthGlobeWidgetState extends State<EarthGlobeWidget> with SingleTickerProviderStateMixin {
  late FlutterEarthGlobeController _controller;
  bool _isDisposed = false;
  final Map<String, AnimationController> _beamAnimations = {};

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: true,
      isBackgroundFollowingSphereRotation: true,
    );
    _controller.loadSurface(Image.asset('assets/earth_texture.jpg').image);
  }

  Future<void> addTransferBeam(double fromLat, double fromLng, double toLat, double toLng, {Color? color, Duration? duration}) async {
    if (!_isDisposed && mounted) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final beamId = 'beam_$timestamp';
      final transferDuration = duration ?? const Duration(seconds: 2);
      
      // 添加起点标记
      _controller.addPoint(Point(
        id: 'from_$timestamp',
        coordinates: GlobeCoordinates(fromLat, fromLng),
        style: PointStyle(color: color ?? Colors.cyan, size: 5),
      ));
      
      // 添加终点标记
      _controller.addPoint(Point(
        id: 'to_$timestamp',
        coordinates: GlobeCoordinates(toLat, toLng),
        style: PointStyle(color: color ?? Colors.orange, size: 5),
      ));
      
      // 流星动画
      await _animateMovingLight(fromLat, fromLng, toLat, toLng, beamId, color ?? Colors.cyan, transferDuration);
      
      // 流星到达后清除轨迹
      _controller.removePoint('from_$timestamp');
      _controller.removePoint('to_$timestamp');
    }
  }

  Future<void> _animateMovingLight(double fromLat, double fromLng, double toLat, double toLng, String beamId, Color color, Duration duration) async {
    const steps = 30;
    final stepDelay = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    const tailLength = 5;
    
    for (int i = 0; i <= steps; i++) {
      if (_isDisposed || !mounted) break;
      
      final t = i / steps;
      final lat = fromLat + (toLat - fromLat) * t;
      final lng = fromLng + (toLng - fromLng) * t;
      
      // 添加流星头部（最亮）
      final headId = '${beamId}_head_$i';
      _controller.addPoint(Point(
        id: headId,
        coordinates: GlobeCoordinates(lat, lng),
        style: PointStyle(
          color: Colors.white,
          size: 8,
        ),
      ));
      
      // 添加流星拖尾（渐变）
      for (int j = 1; j <= tailLength; j++) {
        if (i - j < 0) continue;
        
        final tailT = (i - j) / steps;
        final tailLat = fromLat + (toLat - fromLat) * tailT;
        final tailLng = fromLng + (toLng - fromLng) * tailT;
        final tailId = '${beamId}_tail_${i}_$j';
        final alpha = (255 * (1 - j / tailLength)).toInt();
        
        _controller.addPoint(Point(
          id: tailId,
          coordinates: GlobeCoordinates(tailLat, tailLng),
          style: PointStyle(
            color: color.withAlpha(alpha),
            size: (8 - j * 1.2).clamp(2, 8),
          ),
        ));
        
        // 移除拖尾点
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isDisposed && mounted) {
            try {
              _controller.removePoint(tailId);
            } catch (_) {}
          }
        });
      }
      
      // 移除头部点
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_isDisposed && mounted) {
          try {
            _controller.removePoint(headId);
          } catch (_) {}
        }
      });
      
      await Future.delayed(stepDelay);
    }
    
    // 清理所有残留点
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isDisposed && mounted) {
      for (int i = 0; i <= steps; i++) {
        try {
          _controller.removePoint('${beamId}_head_$i');
          for (int j = 1; j <= tailLength; j++) {
            _controller.removePoint('${beamId}_tail_${i}_$j');
          }
        } catch (_) {}
      }
    }
  }

  void clearBeams() {
    if (!_isDisposed && mounted) {
      // 清除所有点和连接
      for (var point in List.from(_controller.points)) {
        _controller.removePoint(point.id);
      }
      for (var conn in List.from(_controller.connections)) {
        _controller.removePointConnection(conn.id);
      }
    }
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      for (var controller in _beamAnimations.values) {
        controller.dispose();
      }
      _beamAnimations.clear();
      try {
        _controller.dispose();
      } catch (e) {
        // 忽略重复dispose错误
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterEarthGlobe(
      controller: _controller,
      radius: 150,
    );
  }
}
