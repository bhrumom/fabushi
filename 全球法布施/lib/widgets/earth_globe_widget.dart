import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';

class EarthGlobeWidget extends StatefulWidget {
  const EarthGlobeWidget({super.key});

  @override
  State<EarthGlobeWidget> createState() => EarthGlobeWidgetState();
}

class EarthGlobeWidgetState extends State<EarthGlobeWidget> {
  late FlutterEarthGlobeController _controller;
  final List<String> _pointIds = [];
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: true,
      isBackgroundFollowingSphereRotation: true,
      surface: Image.asset('assets/earth_texture.jpg').image,
    );
  }

  void addTransferBeam(double fromLat, double fromLng, double toLat, double toLng) {
    if (!_isDisposed && mounted) {
      setState(() {
        final id = 'point_${DateTime.now().millisecondsSinceEpoch}';
        _pointIds.add(id);
      });
    }
  }

  void clearBeams() {
    if (!_isDisposed && mounted) {
      setState(() {
        _pointIds.clear();
      });
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
