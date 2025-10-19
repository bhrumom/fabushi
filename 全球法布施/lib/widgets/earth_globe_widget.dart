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

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: true,
      isBackgroundFollowingSphereRotation: true,
      surface: Image.network(
        'https://eoimages.gsfc.nasa.gov/images/imagerecords/73000/73909/world.topo.bathy.200412.3x5400x2700.jpg',
      ).image,
    );
  }

  void addTransferBeam(double fromLat, double fromLng, double toLat, double toLng) {
    setState(() {
      final id = 'point_${DateTime.now().millisecondsSinceEpoch}';
      _pointIds.add(id);
    });
  }

  void clearBeams() {
    setState(() {
      _pointIds.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
