import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:three_js_core/three_js_core.dart' as three;
import 'package:three_js/three_js.dart' as three_full; // 用于CylinderGeometry
import 'package:three_js_math/three_js_math.dart' as tmath;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/asset_loader_service.dart';

class BuddhaModelScreen extends StatefulWidget {
  final bool autoRotate;
  final bool isBurning; // 是否正在燃烧（开始念经后）
  final double incenseProgress; // 香燃烧进度 0.0-1.0
  final bool showBook; // 是否显示经书
  final String? bookTitle; // 经书标题
  final VoidCallback? onBookTap; // 点击经书回调
  final bool isVisible; // 是否可见，用于暂停后台渲染
  
  const BuddhaModelScreen({
    super.key, 
    this.autoRotate = false,
    this.isBurning = false,
    this.incenseProgress = 0.0,
    this.showBook = false,
    this.bookTitle,
    this.onBookTap,
    this.isVisible = true,
  });

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
  
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _loadFailed = false; // 加载失败标记，用于显示重试按钮
  
  // 香相关
  three.Mesh? _incenseStick;
  three.Mesh? _burningTip;
  three.PointLight? _tipLight;
  // Use Points for smoke to allow "particle" effect (fading, size change)
  three.Points? _smokeParticles;
  final int _particleCount = 50;
  final List<double> _particleSpeeds = [];
  Timer? _smokeTimer;
  bool _isBurning = false; // Whether it is burning
  
  // 经书相关
  three.Mesh? _bookMesh;
  bool _showBook = false;
  
  // 香的基准位置
  static const double _incenseBaseX = 0.0;
  static const double _incenseBaseY = -60.0;
  static const double _incenseBaseZ = 80.0;
  static const double _incenseFullHeight = 40.0;
  
  // 经书位置（佛像和香之间）
  static const double _bookBaseX = 0.0;
  static const double _bookBaseY = -55.0;
  static const double _bookBaseZ = 50.0;

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
  
  /// 更新香的燃烧进度（供外部调用）
  void updateIncenseProgress(double progress) {
    _updateIncenseProgress(progress);
  }
  
  /// 设置香的燃烧状态（供外部调用）
  void setBurning(bool burning) {
    _updateBurningState(burning);
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
    
    // 更新香的燃烧状态
    if (oldWidget.isBurning != widget.isBurning) {
      _updateBurningState(widget.isBurning);
    }
    
    // 更新香的燃烧进度
    if (oldWidget.incenseProgress != widget.incenseProgress) {
      _updateIncenseProgress(widget.incenseProgress);
    }
    
    // 更新经书显示状态
    if (oldWidget.showBook != widget.showBook) {
      _updateBookState(widget.showBook);
    }
    
    // 监听可见性变化，优化后台渲染
    if (oldWidget.isVisible != widget.isVisible) {
      _updateVisibilityState(widget.isVisible);
    }
  }

  void _updateVisibilityState(bool isVisible) {
    debugPrint('👁️ 佛像3D层可见性变化: $isVisible');
    try {
      threeJs.pause = !isVisible;
    } catch (e) {
      debugPrint('⚠️ 暂停 ThreeJs 失败: $e');
    }
    
    if (isVisible) {
      // 恢复定时器
      if (_isAutoRotating && _autoRotateTimer == null) {
        _startAutoRotate();
      }
      if (_isBurning && _smokeTimer == null) {
        _startSmokeAnimation();
      }
    } else {
      // 暂停定时器以节省 CPU
      _autoRotateTimer?.cancel();
      _autoRotateTimer = null;
      _smokeTimer?.cancel();
      _smokeTimer = null;
    }
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    debugPrint('🎬 启动绕佛旋转');
    _isReturningToStart = false;
    _autoRotateTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
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
    
    // 创建香（初始隐藏）
    _createIncense();
    
    // 创建经书
    _createBook();
  }
  
  /// Create 3D Incense - Improved Realism
  void _createIncense() {
    // Incense Stick - Slender cylinder
    // Real incense is very thin, approx radius 0.2-0.3, height 40
    // Adjusted: Thinner (0.15)
    final stickGeometry = three_full.CylinderGeometry(0.15, 0.15, _incenseFullHeight, 16);
    final stickMaterial = three.MeshStandardMaterial.fromMap({
      'color': 0x8B5A2B,  // Standard Incense Brown (lighter, more natural)
      'roughness': 1.0, 
      'metalness': 0.0,
    });
    _incenseStick = three.Mesh(stickGeometry, stickMaterial);
    _incenseStick!.position.setValues(
      _incenseBaseX,
      _incenseBaseY + _incenseFullHeight / 2,
      _incenseBaseZ,
    );
    _incenseStick!.visible = true;
    threeJs.scene.add(_incenseStick!);

    // Burning Tip - Glowing ember
    // Slightly wider than the stick to simulate ash/burning head
    final tipGeometry = three_full.CylinderGeometry(0.16, 0.16, 0.8, 16);
    final tipMaterial = three.MeshBasicMaterial.fromMap({
      'color': 0xFF4500, // OrangeRed
    });
    _burningTip = three.Mesh(tipGeometry, tipMaterial);
    _burningTip!.position.setValues(
      _incenseBaseX,
      _incenseBaseY + _incenseFullHeight,
      _incenseBaseZ,
    );
    _burningTip!.visible = false;
    threeJs.scene.add(_burningTip!);

    // Add a point light to simulate the glow of the ember onto the Buddha/Environment
    _tipLight = three.PointLight(0xFF5500, 2.0, 30); // Orange light, intensity 2, distance 30
    _tipLight!.position.setValues(_burningTip!.position.x, _burningTip!.position.y, _burningTip!.position.z);
    _tipLight!.visible = false;
    threeJs.scene.add(_tipLight!);

    // Smoke Particles
    _createSmokeParticles();
  }
  
  /// Create Smoke Particles
  void _createSmokeParticles() {
    final geometry = three.BufferGeometry();
    final positions = <double>[];
    final opacity = <double>[]; // We'll map 'size' to 'opacity' if possible, or just use positions.
    // In this simple renderer, we might not have per-vertex opacity easily without custom shaders.
    // We will simulate fading by moving them far away or scaling them to 0 if possible.
    // Warning: Flutter ThreeJS might handle PointsMaterial sizeAttenuation.
    
    // Initialize particles at the tip
    for (int i = 0; i < _particleCount; i++) {
        // Start all at base, hidden
        positions.addAll([0, -1000, 0]); 
        _particleSpeeds.add(0.5 + math.Random().nextDouble() * 0.5); // Random speed
    }

    geometry.setAttributeFromString('position', tmath.Float32BufferAttribute.fromList(positions, 3));
    
    // Smoky particle material
    final material = three.PointsMaterial.fromMap({
      'color': 0xEEEEEE, 
      'size': 1.5, // Much finer particles for subtle smoke
      'transparent': true,
      'opacity': 0.3, // Lower opacity
      'sizeAttenuation': true,
      // 'map': texture... (If we had a smoke texture, but sticking to simple circles)
      // 'blending': three.AdditiveBlending, // Better for smoke?
    });
    
    _smokeParticles = three.Points(geometry, material);
    _smokeParticles!.visible = false;
    threeJs.scene.add(_smokeParticles!);
  }
  
  /// 创建3D经书模型
  void _createBook() {
    // 书本主体 - 使用 BoxGeometry 创建长方体
    // 书的尺寸：宽12 x 高2 x 深8
    final bookGeometry = three_full.BoxGeometry(12, 2, 8);
    
    // 古朴的红木色书封
    final bookMaterial = three.MeshStandardMaterial.fromMap({
      'color': 0x8B0000, // 深红色（类似古书）
      'roughness': 0.8,
      'metalness': 0.1,
    });
    
    _bookMesh = three.Mesh(bookGeometry, bookMaterial);
    _bookMesh!.position.setValues(_bookBaseX, _bookBaseY, _bookBaseZ);
    // 微微倾斜，更有立体感
    _bookMesh!.rotation.x = -0.2;
    _bookMesh!.visible = widget.showBook;
    threeJs.scene.add(_bookMesh!);
    
    _showBook = widget.showBook;
  }
  
  /// 设置经书显示状态（供外部调用）
  void setBookVisible(bool visible) {
    _showBook = visible;
    _bookMesh?.visible = visible;
  }
  
  /// 更新经书状态
  void _updateBookState(bool showBook) {
    if (_showBook != showBook) {
      _showBook = showBook;
      _bookMesh?.visible = showBook;
    }
  }
  
  /// 更新香的燃烧状态
  void _updateBurningState(bool burning) {
    _isBurning = burning;
    // Stick is always visible. Tip, Light, and Smoke are only visible when burning.
    _burningTip?.visible = burning;
    _tipLight?.visible = burning;
    _smokeParticles?.visible = burning;
    
    if (burning) {
      _startSmokeAnimation();
    } else {
      _smokeTimer?.cancel();
      _smokeTimer = null;
      // 停止燃烧时重置香的高度
      _resetIncense();
    }
  }
  
  /// 重置香的状态
  void _resetIncense() {
    if (_incenseStick == null) return;
    _incenseStick!.scale.setValues(1, 1, 1);
    _incenseStick!.position.y = _incenseBaseY + _incenseFullHeight / 2;
  }
  
  /// 更新香的燃烧进度 - 使用原来的逻辑
  void _updateIncenseProgress(double progress) {
    if (_incenseStick == null || _burningTip == null || !_isBurning) return;
    
    final remaining = 1.0 - progress;
    final currentHeight = _incenseFullHeight * remaining;
    
    // 更新香柱高度和位置（通过缩放Y轴实现燃烧效果）
    _incenseStick!.scale.setValues(1, remaining.clamp(0.01, 1.0), 1);
    _incenseStick!.position.y = _incenseBaseY + currentHeight / 2;
    
    // Update tip and light position
    if (_burningTip != null) {
      _burningTip!.position.y = _incenseBaseY + currentHeight;
      _burningTip!.visible = _isBurning && remaining > 0.01;
      
      if (_tipLight != null) {
        _tipLight!.position.setValues(_burningTip!.position.x, _burningTip!.position.y, _burningTip!.position.z);
        _tipLight!.visible = _burningTip!.visible;
      }
    }
  }
  
  /// 启动烟雾动画
  void _startSmokeAnimation() {
    _smokeTimer?.cancel();
    _smokeTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted || !_isBurning) {
        timer.cancel();
        return;
      }
      _animateSmoke();
    });
  }
  
  /// Smoke Animation - Particle System
  void _animateSmoke() {
    if (_smokeParticles == null || _burningTip == null) return;
    
    final positions = _smokeParticles!.geometry!.getAttributeFromString('position');
    final array = positions.array;
    final tipPos = _burningTip!.position;
    final time = DateTime.now().millisecondsSinceEpoch * 0.001;
    
    // Wind factors
    final windX = math.sin(time * 0.5) * 0.5;
    final windZ = math.cos(time * 0.3) * 0.3;

    for (int i = 0; i < _particleCount; i++) {
        // Read current pos
        double px = array[i * 3];
        double py = array[i * 3 + 1];
        double pz = array[i * 3 + 2];
        
        // If particle is "dead" (too high) or hidden (y < -500), reset to tip
        // Increased height limit from +15.0 to +45.0 for longer smoke trail
        if (py > tipPos.y + 45.0 || py < -500) {
            // Reset to tip with slight random offset
            px = tipPos.x + (math.Random().nextDouble() - 0.5) * 0.5;
            py = tipPos.y + (math.Random().nextDouble() * 2.0); // Start slightly above
            pz = tipPos.z + (math.Random().nextDouble() - 0.5) * 0.5;
        } else {
            // Move up
            final speed = _particleSpeeds[i];
            py += speed * 0.6; // Slightly faster upward speed

            // Wind/Drift
            final heightFactor = (py - tipPos.y) / 45.0; // 0 to 1 based on new height
            px += windX * heightFactor * 1.5 + math.sin(time * 2.0 + py * 0.5) * 0.1;
            pz += windZ * heightFactor * 1.5 + math.cos(time * 1.5 + py * 0.5) * 0.1;
        }
        
        array[i * 3] = px;
        array[i * 3 + 1] = py;
        array[i * 3 + 2] = pz;
    }
    
    positions.needsUpdate = true;
  }

  void _addStars() {
    final geometry = three.BufferGeometry();
    final vertices = <double>[];
    final random = math.Random();

    for (int i = 0; i < 300; i++) {
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

  /// 加载佛像模型（带自动重试）
  Future<void> _loadModel() async {
    const maxRetries = 3;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('开始加载佛像模型 (第 $attempt/$maxRetries 次尝试, kIsWeb: $kIsWeb)');
        if (mounted) {
          setState(() {
            _isLoading = true;
            _loadFailed = false;
            _loadingProgress = 0.0;
          });
        }
        
        final modelData = await AssetLoaderService.loadBuddhaModel(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
        );
        
        if (!mounted) return;
        
        final loader = GLTFLoader();
        final gltf = await loader.fromBytes(modelData.buffer.asUint8List());
        debugPrint('GLTF 解析结果: ${gltf != null ? "成功" : "失败"}');

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
        
        // 加载成功，清除加载状态
        if (mounted) setState(() => _isLoading = false);
        return; // 成功，退出重试循环
        
      } catch (e, stackTrace) {
        debugPrint('❌ 加载模型失败 (第 $attempt/$maxRetries 次): $e');
        debugPrint('堆栈: $stackTrace');
        
        if (attempt < maxRetries) {
          // 指数退避: 2s -> 4s -> 8s
          final delay = Duration(seconds: 1 << attempt);
          debugPrint('🔄 ${delay.inSeconds} 秒后重试...');
          if (mounted) {
            setState(() {
              _loadingProgress = 0.0;
            });
          }
          await Future.delayed(delay);
          if (!mounted) return;
        } else {
          // 所有重试都失败，显示重试按钮
          debugPrint('❌ 所有重试均失败，显示手动重试按钮');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _loadFailed = true;
            });
          }
        }
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = null;
    _smokeTimer?.cancel();
    _smokeTimer = null;
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
      child: Stack(
        children: [
          Container(
            color: const Color(0xFF0B0E14), // 深蓝色背景作为后备
            child: threeJs.build(),
          ),
          // 经书名称和点击区域（覆盖在3D经书模型上方）
          if (widget.showBook && widget.bookTitle != null && !_isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * 0.28, // 定位在3D经书模型附近
              child: GestureDetector(
                onTap: widget.onBookTap,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B0000).withOpacity(0.85),
                          const Color(0xFF5C0000).withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.bookTitle!,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '点击阅读',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0B0E14).withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFFFD700), // 金色
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '恭请佛像... ${(_loadingProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 加载失败 — 显示重试按钮
          if (_loadFailed && !_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0B0E14).withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: Color(0xFFFFD700),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '佛像加载失败',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '请检查网络连接后重试\n已下载部分将自动续传',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _loadFailed = false;
                          });
                          _loadModel();
                        },
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('重新加载'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
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
