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
    // 设置相机
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width / threeJs.height, 0.1, 10000);
    threeJs.camera.position.setValues(0, 100, 300);
    
    // 创建场景
    threeJs.scene = three.Scene();
    threeJs.scene.background = tmath.Color.fromHex32(0x3E2723);
    
    // 添加环境光
    final ambientLight = three.AmbientLight(0xffffff, 0.8);
    threeJs.scene.add(ambientLight);
    
    // 添加方向光
    final directionalLight = three.DirectionalLight(0xffd700, 1.5);
    directionalLight.position.setValues(0, 200, 100);
    threeJs.scene.add(directionalLight);
    
    // 添加点光源
    final pointLight = three.PointLight(0xffd700, 1.0);
    pointLight.distance = 500;
    pointLight.position.setValues(0, 150, 0);
    threeJs.scene.add(pointLight);
    
    // 加载模型
    await _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final loader = GLTFLoader();
      final gltf = await loader.fromAsset('assets/models/佛像模型.glb');
      
      if (gltf != null && gltf.scene != null) {
        final scene = gltf.scene!;
        scene.scale.setValues(0.5, 0.5, 0.5);
        threeJs.scene.add(scene);
        
        // 设置材质为金色
        scene.traverse((child) {
          if (child is three.Mesh && child.material != null) {
            if (child.material is three.MeshStandardMaterial) {
              final mat = child.material as three.MeshStandardMaterial;
              mat.metalness = 0.9;
              mat.roughness = 0.1;
              mat.color = tmath.Color.fromHex32(0xFFD700);
            }
          }
        });
        
        // 添加动画 - 自动旋转
        threeJs.addAnimationEvent((dt) {
          scene.rotation.y += 0.01;
        });
      }
    } catch (e) {
      debugPrint('加载模型失败: $e');
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
      body: threeJs.build(),
    );
  }
}
