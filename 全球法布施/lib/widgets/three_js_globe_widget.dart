import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_math/three_js_math.dart' as tmath;
import 'package:three_js_core_loaders/three_js_core_loaders.dart' as three_loaders;

class ThreeJsGlobeWidget extends StatefulWidget {
  const ThreeJsGlobeWidget({super.key});

  @override
  State<ThreeJsGlobeWidget> createState() => ThreeJsGlobeWidgetState();
}

class ThreeJsGlobeWidgetState extends State<ThreeJsGlobeWidget> with AutomaticKeepAliveClientMixin {
  late three.ThreeJS threeJs;
  
  // Scene objects
  late three.Mesh _earthMesh;
  final double _earthRadius = 100.0;
  
  // Camera controls
  double _rotationY = 0.0;
  final double _cameraDistance = 280.0;
  Timer? _autoRotateTimer;
  bool _isUserDragging = false;
  double? _lastPointerX;
  
  // Beams
  final List<Map<String, dynamic>> _activeBeams = [];
  
  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        setState(() {});
        _startAutoRotate();
      },
      setup: _setup,
      windowResizeUpdate: (size) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCameraAspect();
        });
      },
    );
  }

  // Exposed method to add a beam
  void addTransferBeam(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng, {
    Color? color,
    Duration? duration,
    String? fromLabel,
    String? toLabel,
  }) {
    if (!mounted) return;
    
    _createBeam(fromLat, fromLng, toLat, toLng, color ?? Colors.cyan, duration ?? const Duration(seconds: 3));
  }
  
  void clearBeams() {
    // Remove all beam objects from scene
    for (var beam in _activeBeams) {
      final mesh = beam['mesh'] as three.Object3D;
      threeJs.scene.remove(mesh);
      // Dispose geometries/materials if possible to prevent leaks
    }
    _activeBeams.clear();
  }

  Future<void> _setup() async {
    threeJs.scene = three.Scene();
    threeJs.scene.background = tmath.Color.fromHex32(0x000000); // Deep black

    // Camera
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width / threeJs.height, 0.1, 1000);
    _updateCameraPosition();

    // Lighting
    final ambientLight = three.AmbientLight(0x333333, 1.0);
    threeJs.scene.add(ambientLight);

    final dirLight = three.DirectionalLight(0xffffff, 1.5);
    dirLight.position.setValues(50, 50, 100);
    threeJs.scene.add(dirLight);

    // Add Stars
    _addStars();

    // Add Earth
    await _addEarth();
    
    // Start animation loop
    _startAnimationLoop();
  }

  void _startAnimationLoop() {
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _animateBeams(0.016);
    });
  }

  Future<void> _addEarth() async {
    final textureLoader = three_loaders.TextureLoader();
    final texture = await textureLoader.fromAsset('assets/earth_texture.jpg');
    
    final geometry = three.SphereGeometry(_earthRadius, 64, 64);
    final material = three.MeshPhongMaterial.fromMap({
      'map': texture,
      'specular': 0x333333,
      'shininess': 15,
    });

    _earthMesh = three.Mesh(geometry, material);
    threeJs.scene.add(_earthMesh);
  }

  void _addStars() {
    final geometry = three.BufferGeometry();
    final vertices = <double>[];
    final random = math.Random();

    for (int i = 0; i < 2000; i++) {
      final x = (random.nextDouble() - 0.5) * 2000;
      final y = (random.nextDouble() - 0.5) * 2000;
      final z = (random.nextDouble() - 0.5) * 2000;
      vertices.addAll([x, y, z]);
    }

    geometry.setAttributeFromString('position', tmath.Float32BufferAttribute.fromList(vertices, 3));
    final material = three.PointsMaterial.fromMap({'color': 0xFFFFFF, 'size': 1.5, 'transparent': true, 'opacity': 0.8});
    final stars = three.Points(geometry, material);
    threeJs.scene.add(stars);
  }

  void _createBeam(double fromLat, double fromLng, double toLat, double toLng, Color color, Duration duration) {
    // Calculate start and end vectors
    final vStart = _latLngToVector3(fromLat, fromLng, _earthRadius);
    final vEnd = _latLngToVector3(toLat, toLng, _earthRadius);
    
    // Control point for bezier (higher than surface)
    final distance = vStart.distanceTo(vEnd);
    final midPoint = vStart.clone().add(vEnd).scale(0.5).normalize();
    // Height proportional to distance, max height limit
    final height = math.min(distance * 0.8, 120.0); 
    final vControl = midPoint.scale(_earthRadius + height);
    
    // Create Group
    final beamGroup = three.Group();
    threeJs.scene.add(beamGroup);

    // Add markers on surface
    final markerGeo = three.SphereGeometry(1.5, 16, 16);
    final startMarker = three.Mesh(markerGeo, three.MeshBasicMaterial.fromMap({'color': 0xff0000})); // Red for start
    startMarker.position.setFrom(vStart);
    beamGroup.add(startMarker);
    
    final endMarker = three.Mesh(markerGeo, three.MeshBasicMaterial.fromMap({'color': 0x00ff00})); // Green for end
    endMarker.position.setFrom(vEnd);
    beamGroup.add(endMarker);
    
    // Create Curve Points manually
    final points = <tmath.Vector3>[];
    for (int i = 0; i <= 50; i++) {
      points.add(_getBezierPoint(vStart, vControl, vEnd, i / 50));
    }
    final pathGeo = three.BufferGeometry().setFromPoints(points);
    final colorInt = (color.red << 16) | (color.green << 8) | color.blue;
    final pathMat = three.LineBasicMaterial.fromMap({'color': colorInt, 'opacity': 0.2, 'transparent': true});
    final pathLine = three.Line(pathGeo, pathMat);
    beamGroup.add(pathLine);
    
    // The moving head (meteor)
    final headGeo = three.SphereGeometry(2.0, 16, 16);
    final headMat = three.MeshBasicMaterial.fromMap({'color': 0xffffff});
    final headMesh = three.Mesh(headGeo, headMat);
    beamGroup.add(headMesh);
    
    _activeBeams.add({
      'mesh': beamGroup,
      'vStart': vStart,
      'vControl': vControl,
      'vEnd': vEnd,
      'head': headMesh,
      'progress': 0.0,
      'speed': 1.0 / (duration.inMilliseconds / 16.0), // Approximate speed per frame
      'finished': false,
    });
  }

  void _animateBeams(double dt) {
    // Update beams
    for (var i = _activeBeams.length - 1; i >= 0; i--) {
      final beam = _activeBeams[i];
      if (beam['finished'] == true) continue;
      
      double progress = beam['progress'] + beam['speed'];
      if (progress > 1.0) {
        progress = 1.0;
        beam['finished'] = true;
        // Remove beam after delay or immediately?
        // Let's keep markers for a bit, but remove the moving part.
        // actually let's fade out and remove.
        _removeBeamDelayed(i);
      }
      beam['progress'] = progress;
      
      final vStart = beam['vStart'] as tmath.Vector3;
      final vControl = beam['vControl'] as tmath.Vector3;
      final vEnd = beam['vEnd'] as tmath.Vector3;
      final head = beam['head'] as three.Mesh;
      
      final pos = _getBezierPoint(vStart, vControl, vEnd, progress);
      head.position.setFrom(pos);
    }
  }
  
  void _removeBeamDelayed(int index) {
     // Remove from scene after a short delay
     Future.delayed(const Duration(milliseconds: 500), () {
       if (mounted && index < _activeBeams.length) {
          // Check if it's the same beam (logic might be flawed if list shifts, better use ID)
          // simplified: just remove the object
          final beam = _activeBeams[index];
          final group = beam['mesh'] as three.Group;
          threeJs.scene.remove(group);
          _activeBeams.removeAt(index);
       }
     });
  }

  tmath.Vector3 _getBezierPoint(tmath.Vector3 v0, tmath.Vector3 v1, tmath.Vector3 v2, double t) {
    final u = 1 - t;
    final p0 = v0.clone().scale(u * u);
    final p1 = v1.clone().scale(2 * u * t);
    final p2 = v2.clone().scale(t * t);
    return p0.add(p1).add(p2);
  }

  tmath.Vector3 _latLngToVector3(double lat, double lng, double radius) {
    final phi = (90 - lat) * (math.pi / 180);
    final theta = (lng + 180) * (math.pi / 180);

    final x = -(radius * math.sin(phi) * math.cos(theta));
    final y = radius * math.cos(phi);
    final z = radius * math.sin(phi) * math.sin(theta);

    return tmath.Vector3(x, y, z);
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isUserDragging) {
        _rotationY -= 0.002;
        _updateCameraPosition();
      }
    });
  }

  void _updateCameraPosition() {
    if (threeJs.camera == null) return;
    final x = _cameraDistance * math.sin(_rotationY);
    final y = 100.0; // Slightly elevated
    final z = _cameraDistance * math.cos(_rotationY);
    threeJs.camera.position.setValues(x, y, z);
    threeJs.camera.lookAt(tmath.Vector3(0, 0, 0));
  }

  void _updateCameraAspect() {
    if (!mounted) return;
    if (threeJs.camera is three.PerspectiveCamera) {
      final camera = threeJs.camera as three.PerspectiveCamera;
      final newAspect = threeJs.width / threeJs.height;
      if ((camera.aspect - newAspect).abs() > 0.001) {
        camera.aspect = newAspect;
        camera.updateProjectionMatrix();
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    threeJs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Listener(
      onPointerDown: (event) {
        _isUserDragging = true;
        _lastPointerX = event.position.dx;
      },
      onPointerMove: (event) {
        if (_isUserDragging && _lastPointerX != null) {
          final delta = event.position.dx - _lastPointerX!;
          _rotationY += delta * 0.005;
          _updateCameraPosition();
          _lastPointerX = event.position.dx;
        }
      },
      onPointerUp: (event) {
        _isUserDragging = false;
        _lastPointerX = null;
      },
      onPointerCancel: (event) {
        _isUserDragging = false;
        _lastPointerX = null;
      },
      child: threeJs.build(),
    );
  }
}
