import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as tmath;

class Incense3DWidget extends StatefulWidget {
  final double progress; // 0.0 to 1.0 (0 = full, 1 = burnt)

  const Incense3DWidget({
    Key? key,
    required this.progress,
  }) : super(key: key);

  @override
  State<Incense3DWidget> createState() => _Incense3DWidgetState();
}

class _Incense3DWidgetState extends State<Incense3DWidget> {
  late three.ThreeJS threeJs;
  three.Mesh? _incenseStick;
  three.Mesh? _burningTip;
  
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) setState(() {});
        _startAnimationLoop();
      },
      setup: _setup,
      windowResizeUpdate: (size) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCameraAspect();
        });
      },
    );
  }

  @override
  void didUpdateWidget(Incense3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _updateIncenseState();
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    threeJs.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    // Scene
    threeJs.scene = three.Scene();
    threeJs.scene.background = null; // Transparent background

    // Camera
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width / threeJs.height, 0.1, 1000);
    threeJs.camera.position.setValues(0, 10, 20);
    threeJs.camera.lookAt(tmath.Vector3(0, 5, 0));

    // Lights
    final ambientLight = three.AmbientLight(0xFFFFFF, 0.8);
    threeJs.scene.add(ambientLight);

    final dirLight = three.DirectionalLight(0xFFFFFF, 1.0);
    dirLight.position.setValues(5, 10, 7);
    threeJs.scene.add(dirLight);

    // Incense Stick (Cylinder)
    final stickGeometry = three.CylinderGeometry(0.2, 0.2, 10, 16);
    final stickMaterial = three.MeshStandardMaterial.fromMap({
      'color': 0x8B4513, // SaddleBrown
      'roughness': 0.8,
    });
    _incenseStick = three.Mesh(stickGeometry, stickMaterial);
    _incenseStick!.position.y = 5; // Center at 5 so bottom is at 0
    threeJs.scene.add(_incenseStick);

    // Burning Tip (Glowing Cylinder)
    final tipGeometry = three.CylinderGeometry(0.21, 0.21, 0.5, 16);
    final tipMaterial = three.MeshBasicMaterial.fromMap({
      'color': 0xFF4500, // OrangeRed
    });
    _burningTip = three.Mesh(tipGeometry, tipMaterial);
    _burningTip!.position.y = 10; // Start at top
    threeJs.scene.add(_burningTip);

    // Smoke Line
    _initSmoke();

    _updateIncenseState();
  }

  three.Line? _smokeLine;
  final int _lineSegmentCount = 200; // Smoother line
  final List<double> _linePositions = [];

  void _initSmoke() {
    final geometry = three.BufferGeometry();
    // Initialize positions array
    for (int i = 0; i < _lineSegmentCount; i++) {
      _linePositions.addAll([0, 0, 0]);
    }

    geometry.setAttributeFromString('position', tmath.Float32BufferAttribute.fromList(_linePositions, 3));
    
    final material = three.LineBasicMaterial.fromMap({
      'color': 0xEEEEEE, // Brighter white
      'linewidth': 3.0, 
      'transparent': true,
      'opacity': 0.8, // Much more visible
    });

    _smokeLine = three.Line(geometry, material);
    threeJs.scene.add(_smokeLine);
  }

  void _updateIncenseState() {
    if (_incenseStick == null || _burningTip == null) return;

    final remaining = 1.0 - widget.progress;
    final currentHeight = 10.0 * remaining;
    
    _incenseStick!.scale.setValues(1, remaining, 1);
    _incenseStick!.position.y = currentHeight / 2;

    _burningTip!.position.y = currentHeight;
    _burningTip!.visible = remaining > 0.01;
  }

  void _startAnimationLoop() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _animateSmoke();
    });
  }

  void _animateSmoke() {
    if (_smokeLine == null || _burningTip == null) return;

    final positions = _smokeLine!.geometry!.getAttributeFromString('position');
    final array = positions.array;
    final tipPos = _burningTip!.position;
    final time = DateTime.now().millisecondsSinceEpoch * 0.001;

    // Dynamic wind parameters
    final windX = math.sin(time * 0.5) * 1.5; // Slow shifting wind X
    final windZ = math.cos(time * 0.3) * 1.0; // Slow shifting wind Z

    for (int i = 0; i < _lineSegmentCount; i++) {
      // Calculate height for this segment
      final heightOffset = i * 0.1; // Longer smoke trail
      final y = tipPos.y + heightOffset;
      
      // Normalized height factor (0 at bottom, 1 at top)
      final hFactor = i / _lineSegmentCount;
      
      // Complex wave motion (sum of sines)
      final wave1 = math.sin(time * 2.0 + heightOffset * 0.8);
      final wave2 = math.cos(time * 1.5 + heightOffset * 1.2);
      final wave3 = math.sin(time * 0.5 + heightOffset * 0.3); // Low freq sway
      
      // Amplitude increases with height (diffusion)
      final amplitude = heightOffset * 0.15;
      
      // Wind effect increases with height
      final driftX = windX * hFactor * hFactor * 5.0; // Quadratic wind influence
      final driftZ = windZ * hFactor * hFactor * 3.0;

      final x = tipPos.x + (wave1 + wave2 + wave3) * amplitude + driftX;
      final z = tipPos.z + (wave1 - wave2) * amplitude + driftZ;

      array[i * 3] = x;
      array[i * 3 + 1] = y;
      array[i * 3 + 2] = z;
    }

    positions.needsUpdate = true;
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
  Widget build(BuildContext context) {
    return threeJs.build();
  }
}
