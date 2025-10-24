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
    );
  }

  Future<void> _setup() async {
    // 创建场景（必须先创建）
    threeJs.scene = three.Scene();
    threeJs.scene.background = tmath.Color.fromHex32(0x3E2723);
    
    // 设置相机
    threeJs.camera = three.PerspectiveCamera(75, threeJs.width / threeJs.height, 0.1, 2000);
    threeJs.camera.position.setValues(0, 50, 200);
    threeJs.camera.lookAt(threeJs.scene.position);
    
    // 添加强环境光
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
      debugPrint('开始加载模型...');
      final loader = GLTFLoader();
      final gltf = await loader.fromAsset('assets/models/佛像模型.glb');
      
      debugPrint('模型加载完成: ${gltf != null}');
      
      if (gltf != null && gltf.scene != null) {
        final scene = gltf.scene!;
        
        threeJs.scene.add(scene);
        
        // 计算模型边界框
        scene.traverse((child) {
          if (child is three.Mesh) {
            child.geometry?.computeBoundingBox();
            final bbox = child.geometry?.boundingBox;
            if (bbox != null) {
              final min = bbox.min;
              final max = bbox.max;
              debugPrint('模型边界: min(${min.x}, ${min.y}, ${min.z}) max(${max.x}, ${max.y}, ${max.z})');
              
              // 计算中心和大小
              final centerX = (min.x + max.x) / 2;
              final centerY = (min.y + max.y) / 2;
              final centerZ = (min.z + max.z) / 2;
              final sizeX = max.x - min.x;
              final sizeY = max.y - min.y;
              final sizeZ = max.z - min.z;
              final maxSize = [sizeX, sizeY, sizeZ].reduce((a, b) => a > b ? a : b);
              
              debugPrint('模型中心: ($centerX, $centerY, $centerZ)');
              debugPrint('模型大小: ($sizeX, $sizeY, $sizeZ), 最大: $maxSize');
              
              // 先缩放再居中（重要！）
              final targetSize = 80.0;
              final scale = targetSize / maxSize;
              scene.scale.setValues(scale, scale, scale);
              
              // 缩放后再居中
              scene.position.setValues(-centerX * scale, -centerY * scale, -centerZ * scale);
              
              debugPrint('应用缩放: $scale, 居中位置: (${-centerX * scale}, ${-centerY * scale}, ${-centerZ * scale})');
              
              // 调整相机
              threeJs.camera.position.setValues(0, 0, 200);
              threeJs.camera.lookAt(threeJs.scene.position);
              debugPrint('相机位置: (0, 0, 200)');
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
        
        setState(() {}); // 强制刷新UI
      } else {
        debugPrint('模型或场景为空');
      }
    } catch (e, stackTrace) {
      debugPrint('加载模型失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  @override
  void dispose() {
    try {
      threeJs.dispose();
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
      body: threeJs.build(),
    );
  }
}
