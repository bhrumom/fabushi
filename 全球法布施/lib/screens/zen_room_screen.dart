import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;
import 'package:three_js_objects/three_js_objects.dart' as three_objects;

class ZenRoomScreen extends StatefulWidget {
  const ZenRoomScreen({super.key});

  @override
  State<ZenRoomScreen> createState() => _ZenRoomScreenState();
}

class _ZenRoomScreenState extends State<ZenRoomScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  three.Scene? _scene;
  three.PerspectiveCamera? _camera;
  three.WebGLRenderer? _renderer;
  bool _isLoading = true;
  String _loadingStatus = '正在初始化禅室...';

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    
    _initScene();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _renderer?.dispose();
    super.dispose();
  }

  Future<void> _initScene() async {
    try {
      setState(() => _loadingStatus = '创建场景...');
      
      // 创建场景
      _scene = three.Scene();
      _scene!.background = three.Color(0x1a1a1a);
      
      // 创建相机
      _camera = three.PerspectiveCamera(
        75,
        MediaQuery.of(context).size.width / MediaQuery.of(context).size.height,
        0.1,
        1000,
      );
      _camera!.position.set(0, 2, 5);
      _camera!.lookAt(three_math.Vector3(0, 1, 0));
      
      // 添加环境光
      final ambientLight = three.AmbientLight(0xffffff, 0.6);
      _scene!.add(ambientLight);
      
      // 添加方向光（模拟窗户光线）
      final directionalLight = three.DirectionalLight(0xfff5e6, 0.8);
      directionalLight.position.set(5, 10, 5);
      directionalLight.castShadow = true;
      _scene!.add(directionalLight);
      
      // 添加点光源（模拟蜡烛）
      final pointLight1 = three.PointLight(0xffaa00, 0.5, 10);
      pointLight1.position.set(-2, 1, 2);
      _scene!.add(pointLight1);
      
      final pointLight2 = three.PointLight(0xffaa00, 0.5, 10);
      pointLight2.position.set(2, 1, 2);
      _scene!.add(pointLight2);
      
      setState(() => _loadingStatus = '构建禅室...');
      
      // 创建地板
      _createFloor();
      
      // 创建墙壁
      _createWalls();
      
      // 创建佛台
      _createAltar();
      
      setState(() => _loadingStatus = '加载佛像模型...');
      
      // 加载佛像模型
      await _loadBuddhaModel();
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      debugPrint('初始化场景失败: $e');
      setState(() {
        _loadingStatus = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  void _createFloor() {
    // 木质地板
    final floorGeometry = three.PlaneGeometry(20, 20);
    final floorMaterial = three.MeshStandardMaterial(
      color: 0x8B4513,
      roughness: 0.8,
      metalness: 0.2,
    );
    final floor = three.Mesh(floorGeometry, floorMaterial);
    floor.rotation.x = -3.14159 / 2;
    floor.receiveShadow = true;
    _scene!.add(floor);
  }

  void _createWalls() {
    // 后墙
    final backWallGeometry = three.PlaneGeometry(20, 8);
    final wallMaterial = three.MeshStandardMaterial(
      color: 0xF5E6D3,
      roughness: 0.9,
    );
    final backWall = three.Mesh(backWallGeometry, wallMaterial);
    backWall.position.set(0, 4, -10);
    backWall.receiveShadow = true;
    _scene!.add(backWall);
    
    // 左墙
    final leftWall = three.Mesh(backWallGeometry, wallMaterial);
    leftWall.position.set(-10, 4, 0);
    leftWall.rotation.y = 3.14159 / 2;
    leftWall.receiveShadow = true;
    _scene!.add(leftWall);
    
    // 右墙
    final rightWall = three.Mesh(backWallGeometry, wallMaterial);
    rightWall.position.set(10, 4, 0);
    rightWall.rotation.y = -3.14159 / 2;
    rightWall.receiveShadow = true;
    _scene!.add(rightWall);
  }

  void _createAltar() {
    // 佛台底座
    final altarGeometry = three.BoxGeometry(3, 0.5, 2);
    final altarMaterial = three.MeshStandardMaterial(
      color: 0x8B0000,
      roughness: 0.3,
      metalness: 0.5,
    );
    final altar = three.Mesh(altarGeometry, altarMaterial);
    altar.position.set(0, 0.25, -5);
    altar.castShadow = true;
    altar.receiveShadow = true;
    _scene!.add(altar);
    
    // 佛台上层
    final altarTopGeometry = three.BoxGeometry(2.5, 0.3, 1.5);
    final altarTop = three.Mesh(altarTopGeometry, altarMaterial);
    altarTop.position.set(0, 0.65, -5);
    altarTop.castShadow = true;
    altarTop.receiveShadow = true;
    _scene!.add(altarTop);
  }

  Future<void> _loadBuddhaModel() async {
    try {
      // 由于 three_js 包在 Flutter 中的 GLTFLoader 支持有限
      // 我们创建一个简单的佛像替代物
      // 实际项目中需要使用 flutter_3d_controller 或其他支持 GLTF 的包
      
      // 创建简单的佛像表示（金色球体 + 圆柱体）
      final bodyGeometry = three.CylinderGeometry(0.3, 0.4, 1.2, 32);
      final bodyMaterial = three.MeshStandardMaterial(
        color: 0xFFD700,
        roughness: 0.3,
        metalness: 0.7,
      );
      final body = three.Mesh(bodyGeometry, bodyMaterial);
      body.position.set(0, 1.4, -5);
      body.castShadow = true;
      _scene!.add(body);
      
      // 头部
      final headGeometry = three.SphereGeometry(0.25, 32, 32);
      final head = three.Mesh(headGeometry, bodyMaterial);
      head.position.set(0, 2.2, -5);
      head.castShadow = true;
      _scene!.add(head);
      
      // 光环
      final haloGeometry = three.TorusGeometry(0.4, 0.02, 16, 100);
      final haloMaterial = three.MeshStandardMaterial(
        color: 0xFFFFAA,
        emissive: 0xFFFFAA,
        emissiveIntensity: 0.5,
      );
      final halo = three.Mesh(haloGeometry, haloMaterial);
      halo.position.set(0, 2.5, -5);
      halo.rotation.x = 3.14159 / 2;
      _scene!.add(halo);
      
      // 添加旋转动画到光环
      _rotationController.addListener(() {
        halo.rotation.z = _rotationController.value * 2 * 3.14159;
      });
      
    } catch (e) {
      debugPrint('加载佛像模型失败: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('🙏 禅室'),
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFD700),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _loadingStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Container(
                color: const Color(0xFF1a1a1a),
                child: CustomPaint(
                  painter: _ZenRoomPainter(_scene, _camera),
                  size: Size.infinite,
                ),
              ),
            ),
          
          // 控制面板
          if (!_isLoading)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.black.withOpacity(0.7),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🕉️ 南无阿弥陀佛 🕉️',
                        style: TextStyle(
                          color: Color(0xFFD700),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '愿此功德回向法界众生，同证菩提',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZenRoomPainter extends CustomPainter {
  final three.Scene? scene;
  final three.PerspectiveCamera? camera;

  _ZenRoomPainter(this.scene, this.camera);

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制简化的禅室场景
    final paint = Paint();
    
    // 背景渐变
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF2a2a2a),
        const Color(0xFF1a1a1a),
      ],
    );
    
    paint.shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // 绘制地板
    paint.shader = null;
    paint.color = const Color(0xFF8B4513);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      paint,
    );
    
    // 绘制佛台
    paint.color = const Color(0xFF8B0000);
    final altarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.55),
        width: size.width * 0.4,
        height: size.height * 0.15,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(altarRect, paint);
    
    // 绘制佛像（简化为金色圆形）
    paint.color = const Color(0xFFD700);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.4),
      size.width * 0.08,
      paint,
    );
    
    // 绘制光环
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = const Color(0xFFFFAA).withOpacity(0.6);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.35),
      size.width * 0.12,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
