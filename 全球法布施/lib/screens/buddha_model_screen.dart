import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js_math/three_js_math.dart' as tmath;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart';
import 'dart:async';
import 'dart:math' as math;

class BuddhaModelScreen extends StatefulWidget {
  final bool autoRotate;
  
  const BuddhaModelScreen({super.key, this.autoRotate = false});

  @override
  State<BuddhaModelScreen> createState() => BuddhaModelScreenState();
}

class BuddhaModelScreenState extends State<BuddhaModelScreen> with AutomaticKeepAliveClientMixin {
  late three.ThreeJS threeJs;
  double _rotationY = 0.0;
  double _cameraDistance = 250.0;
  Timer? _autoRotateTimer;
  bool _isUserDragging = false;
  double? _lastPointerX;
  bool _isAutoRotating = false; // 默认不自动旋转
  int _renderErrorCount = 0; // 渲染错误计数
  DateTime? _lastSuccessfulRender; // 上次成功渲染时间

  /// 获取当前是否正在自动旋转
  bool get isAutoRotating => _isAutoRotating;

  /// 设置自动旋转状态
  void setAutoRotate(bool enabled) {
    debugPrint('🎯 setAutoRotate: $enabled (当前: $_isAutoRotating, timer: ${_autoRotateTimer != null})');
    _isAutoRotating = enabled;
    if (enabled) {
      // 确保启动旋转
      if (_autoRotateTimer == null) {
        _startAutoRotate();
      }
    } else {
      _stopAutoRotate();
    }
  }

  @override
  void initState() {
    super.initState();
    _isAutoRotating = widget.autoRotate;
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        // 根据参数决定是否启动自动旋转
        if (widget.autoRotate) {
          _startAutoRotate();
        }
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

  @override
  void didUpdateWidget(BuddhaModelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('📍 didUpdateWidget: old=${oldWidget.autoRotate}, new=${widget.autoRotate}, current=$_isAutoRotating');
    // 只在 autoRotate 参数真正变化时才更新旋转状态
    if (oldWidget.autoRotate != widget.autoRotate) {
      debugPrint('🔄 绕佛状态变化: ${oldWidget.autoRotate} -> ${widget.autoRotate}');
      setAutoRotate(widget.autoRotate);
    }
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    debugPrint('🎬 启动绕佛旋转');
    _isReturningToStart = false;
    _autoRotateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        debugPrint('⚠️ 组件已卸载，停止旋转');
        timer.cancel();
        _autoRotateTimer = null;
        return;
      }
      
      if (_isUserDragging) return;
      
      // 继续旋转（无论是正常绕佛还是返回原位）
      if (_isAutoRotating || _isReturningToStart) {
        _rotationY -= 0.005;
        _updateCameraPosition();
        
        // 如果正在返回原位，检查是否接近初始位置
        if (_isReturningToStart) {
          // 归一化角度到 0 ~ 2π
          double normalizedRotation = _rotationY % (2 * math.pi);
          if (normalizedRotation < 0) {
            normalizedRotation += 2 * math.pi;
          }
          
          // 检查是否接近 0 或 2π（即初始位置）
          if (normalizedRotation < 0.01 || normalizedRotation > (2 * math.pi - 0.01)) {
            debugPrint('🎯 已返回初始位置，停止旋转');
            _rotationY = 0.0;
            _updateCameraPosition();
            _isReturningToStart = false;
            timer.cancel();
            _autoRotateTimer = null;
          }
        }
      }
    });
  }

  bool _isReturningToStart = false; // 是否正在返回初始位置

  void _stopAutoRotate() {
    // 标记为正在返回初始位置，继续旋转直到回到原位
    _isReturningToStart = true;
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
    if (!mounted) return;
    try {
      if (threeJs.camera == null) return;
      final x = _cameraDistance * math.sin(_rotationY);
      final y = 0.0;
      final z = _cameraDistance * math.cos(_rotationY);
      threeJs.camera.position.setValues(x, y, z);
      threeJs.camera.lookAt(tmath.Vector3(0, 0, 0));
      _lastSuccessfulRender = DateTime.now();
      _renderErrorCount = 0;
    } catch (e) {
      _renderErrorCount++;
      debugPrint('⚠️ 更新相机位置失败 ($_renderErrorCount): $e');
    }
  }

  Future<void> _setup() async {
    // 创建场景
    threeJs.scene = three.Scene();
    // 星空背景 - Match spaceDeepBlue (0x0B0E14)
    threeJs.scene.background = tmath.Color.fromHex32(0x0B0E14);

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
      // 统一使用相同路径，Web 版本的模型放在 web/assets/models/ 目录
      // 原生平台的模型放在 assets/models/ 目录
      const modelPath = 'assets/models/佛像模型.glb';
      debugPrint('开始加载佛像模型: $modelPath (kIsWeb: $kIsWeb)');
      final loader = GLTFLoader();
      final gltf = await loader.fromAsset(modelPath);
      debugPrint('GLTF 加载结果: ${gltf != null ? "成功" : "失败"}');

      if (gltf?.scene != null) {
        debugPrint('场景存在，添加到 threeJs.scene');
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
      debugPrint('❌ 加载模型失败: $e');
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
    // 确保 Timer 状态与 _isAutoRotating 一致
    if (_isAutoRotating && _autoRotateTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isAutoRotating && _autoRotateTimer == null) {
          _startAutoRotate();
        }
      });
    }
    return Listener(
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
      child: Container(
        color: const Color(0xFF0B0E14), // 深蓝色背景作为后备
        child: threeJs.build(),
      ),
    );
  }
}
