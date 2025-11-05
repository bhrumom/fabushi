import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import '../services/country_coordinates_service.dart';
import '../utils/globe_math_utils.dart';
import 'dart:math' as math;

class EnhancedEarthGlobeWidget extends StatefulWidget {
  const EnhancedEarthGlobeWidget({super.key});

  @override
  State<EnhancedEarthGlobeWidget> createState() =>
      EnhancedEarthGlobeWidgetState();
}

class EnhancedEarthGlobeWidgetState extends State<EnhancedEarthGlobeWidget>
    with SingleTickerProviderStateMixin {
  late FlutterEarthGlobeController _controller;
  final CountryCoordinatesService _coordService = CountryCoordinatesService();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: true,
      isBackgroundFollowingSphereRotation: true,
    );
    _controller.loadSurface(Image.asset('assets/earth_texture.jpg').image);
    _coordService.initialize();
  }

  // 添加优美的传输轨迹
  Future<void> addBeautifulTrajectory({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    Color? color,
    Duration? duration,
  }) async {
    if (_isDisposed || !mounted) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final beamColor = color ?? _getRandomBeamColor();
    final animDuration = duration ?? const Duration(seconds: 3);

    // 计算3D坐标
    final start = GlobeMathUtils.latLngToVector3(fromLat, fromLng);
    final end = GlobeMathUtils.latLngToVector3(toLat, toLng);
    final control = GlobeMathUtils.calculateArcControlPoint(
      fromLat,
      fromLng,
      toLat,
      toLng,
      heightFactor: 0.4,
    );

    // 添加起点和终点标记
    _addEndpointMarkers(fromLat, fromLng, toLat, toLng, timestamp);

    // 执行流星动画
    await _animateBeautifulMeteor(
      start,
      control,
      end,
      beamColor,
      animDuration,
      timestamp,
    );

    // 清理标记
    _cleanupMarkers(timestamp);
  }

  void _addEndpointMarkers(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
    int timestamp,
  ) {
    _controller.addPoint(
      Point(
        id: 'from_$timestamp',
        coordinates: GlobeCoordinates(fromLat, fromLng),
        style: PointStyle(color: Colors.red.shade400, size: 8),
      ),
    );

    _controller.addPoint(
      Point(
        id: 'to_$timestamp',
        coordinates: GlobeCoordinates(toLat, toLng),
        style: PointStyle(color: Colors.green.shade400, size: 6),
      ),
    );
  }

  Future<void> _animateBeautifulMeteor(
    v.Vector3 start,
    v.Vector3 control,
    v.Vector3 end,
    Color color,
    Duration duration,
    int timestamp,
  ) async {
    const steps = 60;
    final stepDelay = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    const tailLength = 12;

    for (int i = 0; i <= steps; i++) {
      if (_isDisposed || !mounted) break;

      final t = i / steps;
      final pos = GlobeMathUtils.quadraticBezier(start, control, end, t);
      final coords = _vector3ToGlobeCoords(pos);

      // 彗星头部（白色核心）
      _controller.addPoint(
        Point(
          id: 'head_${timestamp}_$i',
          coordinates: coords,
          style: PointStyle(color: Colors.white, size: 12),
        ),
      );

      // 彗星拖尾（渐变效果）
      for (int j = 1; j <= tailLength; j++) {
        if (i - j < 0) continue;

        final tailT = (i - j) / steps;
        final tailPos = GlobeMathUtils.quadraticBezier(
          start,
          control,
          end,
          tailT,
        );
        final tailCoords = _vector3ToGlobeCoords(tailPos);

        final opacity = (1 - j / tailLength);
        final size = 10 - (j * 0.5);

        _controller.addPoint(
          Point(
            id: 'tail_${timestamp}_${i}_$j',
            coordinates: tailCoords,
            style: PointStyle(
              color: color.withOpacity(opacity),
              size: size.clamp(3, 10),
            ),
          ),
        );

        // 延迟清理拖尾
        Future.delayed(Duration(milliseconds: 200), () {
          if (!_isDisposed && mounted) {
            try {
              _controller.removePoint('tail_${timestamp}_${i}_$j');
            } catch (_) {}
          }
        });
      }

      // 清理头部
      Future.delayed(Duration(milliseconds: 300), () {
        if (!_isDisposed && mounted) {
          try {
            _controller.removePoint('head_${timestamp}_$i');
          } catch (_) {}
        }
      });

      await Future.delayed(stepDelay);
    }
  }

  GlobeCoordinates _vector3ToGlobeCoords(v.Vector3 vec) {
    final r = vec.length;
    final lat = 90 - (math.acos(vec.y / r) * 180 / math.pi);
    final lng = (math.atan2(vec.z, -vec.x) * 180 / math.pi) - 180;
    return GlobeCoordinates(lat, lng);
  }

  Color _getRandomBeamColor() {
    final colors = [
      Colors.cyan,
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.teal,
    ];
    return colors[math.Random().nextInt(colors.length)];
  }

  void _cleanupMarkers(int timestamp) {
    Future.delayed(Duration(milliseconds: 500), () {
      if (!_isDisposed && mounted) {
        try {
          _controller.removePoint('from_$timestamp');
          _controller.removePoint('to_$timestamp');
        } catch (_) {}
      }
    });
  }

  void clearAll() {
    if (!_isDisposed && mounted) {
      for (var point in List.from(_controller.points)) {
        _controller.removePoint(point.id);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      _controller.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterEarthGlobe(controller: _controller, radius: 150);
  }
}
