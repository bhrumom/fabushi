import 'package:flutter/material.dart';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_math/three_js_math.dart' as tmath;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart';
import 'dart:async';

class BuddhaModelScreen extends StatefulWidget {
  const BuddhaModelScreen({super.key});

  @override
  State<BuddhaModelScreen> createState() => _BuddhaModelScreenState();
}

class _BuddhaModelScreenState extends State<BuddhaModelScreen> {
  three.ThreeJS? threeJs;
  three.Object3D? loadedModel;
  Timer? _resizeTimer;
  Size? _currentSize;

  @override
  void initState() {
    super.initState();
    _initThreeJS();
  }

  void _initThreeJS() {
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) setState(() {});
      },
      setup: _setup,
    );
  }

  void _handleResize(Size newSize) {
    if (_currentSize == newSize) return;
    _currentSize = newSize;
    
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          try {
            threeJs?.dispose();
          } catch (e) {}
          _initThreeJS();
        });
      }
    });
  }

  Future<void> _setup() async {
    if (threeJs == null) return;
    
    // 创建场景（必须先创建）
    threeJs!.scene = three.Scene();
    threeJs!.scene.background = tmath.Color.fromHex32(0x3E2723);
    
    // 设置相机
    threeJs!.camera = three.PerspectiveCamera(75, threeJs!.width / threeJs!.height, 0.1, 2000);
    threeJs!.camera.position.setValues(0, 0, 200);
    threeJs!.camera.lookAt(tmath.Vector3(0, 0, 0));
    
    // 添加强环境光
    final ambientLight = three.AmbientLight(0xffffff, 1.5);
    threeJs!.scene.add(ambientLight);
    
    // 添加方向光
    final directionalLight = three.DirectionalLight(0xffffff, 2.0);
    directionalLight.position.setValues(100, 100, 100);
    threeJs!.scene.add(directionalLight);
    
    // 加载模型
    await _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final loader = GLTFLoader();
      final gltf = await loader.fromAsset('assets/models/佛像模型.glb');
      
      if (gltf != null && gltf.scene != null) {
        final scene = gltf.scene!;
        threeJs!.scene.add(scene);
        
        // 计算整个场景的边界框
        double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
        double maxX = double.negativeInfinity, maxY = double.negativeInfinity, maxZ = double.negativeInfinity;
        
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
            
            // 设置材质
            final newMaterial = three.MeshStandardMaterial.fromMap({
              'color': 0xFFD700,
              'metalness': 0.9,
              'roughness': 0.1,
              'side': tmath.DoubleSide,
            });
            child.material = newMaterial;
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
        
        // 缩放并居中
        final targetSize = 80.0;
        final scale = targetSize / maxSize;
        scene.scale.setValues(scale, scale, scale);
        scene.position.setValues(-centerX * scale, -centerY * scale, -centerZ * scale);
      }
    } catch (e, stackTrace) {
      debugPrint('加载模型失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    try {
      threeJs?.dispose();
    } catch (e) {
      debugPrint('Dispose error: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('佛像模型'),
        backgroundColor: Colors.amber[700],
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final newSize = Size(constraints.maxWidth, constraints.maxHeight);
          _handleResize(newSize);
          
          if (threeJs == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: threeJs!.build(),
          );
        },
      ),
    );
  }
}
