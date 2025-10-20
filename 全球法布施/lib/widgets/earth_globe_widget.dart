import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';

class EarthGlobeWidget extends StatefulWidget {
  const EarthGlobeWidget({super.key});

  @override
  State<EarthGlobeWidget> createState() => EarthGlobeWidgetState();
}

class EarthGlobeWidgetState extends State<EarthGlobeWidget> {
  late FlutterEarthGlobeController _controller;
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
  }

  void addTransferBeam(double fromLat, double fromLng, double toLat, double toLng, {Color? color}) {
    if (!_isDisposed && mounted) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      _controller.addPoint(Point(
        id: 'from_$timestamp',
        coordinates: GlobeCoordinates(fromLat, fromLng),
        style: PointStyle(color: color ?? Colors.cyan, size: 4),
      ));
      
      _controller.addPoint(Point(
        id: 'to_$timestamp',
        coordinates: GlobeCoordinates(toLat, toLng),
        style: PointStyle(color: color ?? Colors.orange, size: 4),
      ));
      
      _controller.addPointConnection(
        PointConnection(
          start: GlobeCoordinates(fromLat, fromLng),
          end: GlobeCoordinates(toLat, toLng),
          id: 'conn_$timestamp',
          style: PointConnectionStyle(
            color: color ?? Colors.cyan,
            lineWidth: 2.0,
          ),
        ),
        animateDraw: true,
        animateDrawDuration: const Duration(seconds: 2),
      );
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
