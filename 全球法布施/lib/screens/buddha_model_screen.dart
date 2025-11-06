import 'package:flutter/material.dart';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_math/three_js_math.dart' as tmath;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart';
import 'dart:async';
import 'dart:math' as math;

class BuddhaModelScreen extends StatefulWidget {
  const BuddhaModelScreen({super.key});

  @override
  State<BuddhaModelScreen> createState() => _BuddhaModelScreenState();
}

class _BuddhaModelScreenState extends State<BuddhaModelScreen> with AutomaticKeepAliveClientMixin {
  late three.ThreeJS threeJs;
  double _rotationY = 0.0;
  double _cameraDistance = 250.0;
  Timer? _autoRotateTimer;
  bool _isUserDragging = false;
  double? _lastPointerX;

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        _startAutoRotate();
        if (mounted) setState(() {});
      },
      setup: _setup,
      windowResizeUpdate: (size) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCameraAspect();
        });
      },
    );
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isUserDragging) {
        _rotationY -= 0.005;
        _updateCameraPosition();
      }
    });
  }

  void _updateCameraAspect() {
    if (!mounted) return;
    if (threeJs.camera is three.PerspectiveCamera) {
      final camera = threeJs.camera as three.PerspectiveCamera;
      final newAspect = threeJs.width / threeJs.height;
      if ((camera.aspect - newAspect).abs() > 0.001) {
        camera.aspect = newAspect;
        camera.fov = 50.0;
        camera.updateProjectionMatrix();
      }
    }
  }

  void _updateCameraPosition() {
    if (!mounted || threeJs.camera == null) return;
    final x = _cameraDistance * math.sin(_rotationY);
    final y = 0.0;
    final z = _cameraDistance * math.cos(_rotationY);
    threeJs.camera.position.setValues(x, y, z);
    threeJs.camera.lookAt(tmath.Vector3(0, 0, 0));
  }

  Future<void> _setup() async {
    // 创建场景
    threeJs.scene = three.Scene();
    // 星空背景
    threeJs.scene.background = tmath.Color.fromHex32(0x000428);

    // 添加星星
    _addStars();

    // 设置相机 - 使用较小的FOV以减少透视变形
    threeJs.camera = three.PerspectiveCamera(50, threeJs.width / threeJs.height, 0.1, 2000);
    _updateCameraPosition();

    // 环境光 - 提高亮度
    final ambientLight = three.AmbientLight(0xFFE4B5, 2.5);
    threeJs.scene.add(ambientLight);

    // 主光源 - 从上方照射
    final mainLight = three.DirectionalLight(0xFFFFDD, 3.5);
    mainLight.position.setValues(0, 200, 150);
    threeJs.scene.add(mainLight);

    // 补光 - 从前方
    final frontLight = three.DirectionalLight(0xFFFFFF, 2.0);
    frontLight.position.setValues(0, 50, 200);
    threeJs.scene.add(frontLight);

    // 侧光 - 增强立体感
    final sideLight1 = three.DirectionalLight(0xFFD700, 1.5);
    sideLight1.position.setValues(150, 100, 100);
    threeJs.scene.add(sideLight1);

    final sideLight2 = three.DirectionalLight(0xFFD700, 1.5);
    sideLight2.position.setValues(-150, 100, 100);
    threeJs.scene.add(sideLight2);

    // 加载模型
    await _loadModel();
  }

  void _addStars() {
    final geometry = three.BufferGeometry();
    final vertices = <double>[];
    final random = math.Random();

    for (int i = 0; i < 1000; i++) {
      final x = (random.nextDouble() - 0.5) * 2000;
      final y = (random.nextDouble() - 0.5) * 2000;
      final z = (random.nextDouble() - 0.5) * 2000;
      vertices.addAll([x, y, z]);
    }

    geometry.setAttributeFromString('position', tmath.Float32BufferAttribute.fromList(vertices, 3));
    final material = three.PointsMaterial.fromMap({'color': 0xFFFFFF, 'size': 2});
    final stars = three.Points(geometry, material);
    threeJs.scene.add(stars);
  }

  Future<void> _loadModel() async {
    try {
      final loader = GLTFLoader();
      final gltf = await loader.fromAsset('assets/models/佛像模型.glb');

      if (gltf?.scene != null) {
        final scene = gltf!.scene!;
        threeJs.scene.add(scene);

        // 计算整个场景的边界框
        double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
        double maxX = double.negativeInfinity,
            maxY = double.negativeInfinity,
            maxZ = double.negativeInfinity;

        scene.traverse((child) {
          if (child is three.Mesh) {
            child.geometry?.computeBoundingBox();
            final bbox = child.geometry?.boundingBox;
            if (bbox != null) {
              minX = minX < bbox.min.x ? minX : bbox.min.x;
              minY = minY < bbox.min.y ? minY : bbox.min.y;
              minZ = minZ < bbox.min.z ? minZ : bbox.min.z;
              maxX = maxX > bbox.max.x ? maxX : bbox.max.x;
              maxY = maxY > bbox.max.y ? maxY : bbox.max.y;
              maxZ = maxZ > bbox.max.z ? maxZ : bbox.max.z;
            }

            // 黄金材质
            final goldMaterial = three.MeshStandardMaterial.fromMap({
              'color': 0xFFD700,
              'metalness': 0.9,
              'roughness': 0.2,
              'side': tmath.DoubleSide,
            });
            child.material = goldMaterial;
          }
        });

        // 计算整体中心和大小
        final centerX = (minX + maxX) / 2;
        final centerY = (minY + maxY) / 2;
        final centerZ = (minZ + maxZ) / 2;
        final sizeX = maxX - minX;
        final sizeY = maxY - minY;
        final sizeZ = maxZ - minZ;
        final maxSize = [sizeX, sizeY, sizeZ].reduce((a, b) => a > b ? a : b);

        // 缩放并居中，放大佛像并上移留出供品空间
        const targetSize = 150.0;
        final scale = targetSize / maxSize;
        scene.scale.setValues(scale, scale, scale);
        scene.position.setValues(-centerX * scale, -centerY * scale + 30, -centerZ * scale);
      }
    } catch (e, stackTrace) {
      debugPrint('加载模型失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = null;
    threeJs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Listener(
        onPointerDown: (event) {
          _isUserDragging = true;
          _lastPointerX = event.position.dx;
        },
        onPointerMove: (event) {
          if (_isUserDragging && _lastPointerX != null) {
            final delta = event.position.dx - _lastPointerX!;
            _rotationY += delta * 0.01;
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
        child: SizedBox.expand(child: threeJs.build()),
      ),
    );
  }
}
