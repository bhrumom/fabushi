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
  late three.ThreeJS threeJs;

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: _setup,
      windowResizeUpdate: (size) {
        _updateCameraAspect();
      },
    );
  }

  void _updateCameraAspect() {
    try {
      if (threeJs.camera is three.PerspectiveCamera) {
        final camera = threeJs.camera as three.PerspectiveCamera;
        final newAspect = threeJs.width / threeJs.height;
        if ((camera.aspect - newAspect).abs() > 0.001) {
          camera.aspect = newAspect;
          camera.updateProjectionMatrix();
        }
      }
    } catch (e) {
      // Camera not initialized yet
    }
  }

  Future<void> _setup() async {
    // 创建场景
    threeJs.scene = three.Scene();
    threeJs.scene.background = tmath.Color.fromHex32(0x3E2723);
    
    // 设置相机
    threeJs.camera = three.PerspectiveCamera(75, threeJs.width / threeJs.height, 0.1, 2000);
    threeJs.camera.position.setValues(0, 0, 200);
    threeJs.camera.lookAt(tmath.Vector3(0, 0, 0));
    
    // 添加环境光
    final ambientLight = three.AmbientLight(0xffffff, 1.5);
    threeJs.scene.add(ambientLight);
    
    // 添加方向光
    final directionalLight = three.DirectionalLight(0xffffff, 2.0);
    directionalLight.position.setValues(100, 100, 100);
    threeJs.scene.add(directionalLight);
    
    // 加载模型
    await _loadModel();
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
        const targetSize = 80.0;
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
    threeJs.dispose();
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
      body: SizedBox.expand(
        child: threeJs.build(),
      ),
    );
  }
}
