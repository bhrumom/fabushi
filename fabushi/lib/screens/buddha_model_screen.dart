import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vector;

import '../services/asset_loader_service.dart';
import '../utils/model_auto_fit.dart';

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

class BuddhaModelScreenState extends State<BuddhaModelScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late Scene scene;
  late PerspectiveCamera camera;
  late Ticker _ticker;
  double _lastTime = 0.0;
  
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _loadFailed = false;

  double _rotationY = 0.0;
  double _cameraDistance = 250.0;
  bool _isUserDragging = false;
  double? _lastPointerX;
  bool _isReturningToStart = false;
  bool _isAutoRotating = false;
  double _currentIncenseProgress = 0.0;

  // Book UI
  Offset _bookScreenPos = Offset.zero;
  bool _bookVisibleOnScreen = false;

  // 香和书的基准位置 (3D 坐标)
  static const double _incenseBaseX = 0.0;
  static const double _incenseBaseY = -60.0;
  static const double _incenseBaseZ = 80.0;
  static const double _incenseFullHeight = 40.0;

  static const double _bookBaseX = 0.0;
  static const double _bookBaseY = -55.0;
  static const double _bookBaseZ = 50.0;

  // 烟雾粒子
  final int _particleCount = 50;
  final List<vector.Vector3> _smokeParticles = [];
  final List<double> _particleSpeeds = [];

  // 背景星空点
  final List<vector.Vector3> _stars = [];

  @override
  void initState() {
    super.initState();
    _isAutoRotating = widget.autoRotate;
    _currentIncenseProgress = widget.incenseProgress;
    
    _initScene();
    
    _ticker = createTicker(_onTick);
    if (widget.isVisible) {
      _ticker.start();
    }
  }

  /// 用代码生成纯暖金色环境贴图，确保环境中完全没有蓝色
  static Future<ui.Image> _createGoldenEnvironmentImage() async {
    const int width = 256;
    const int height = 128;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // 底色：深棕色
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF1A0E00),
    );

    // 添加暖金色渐变光晕，模拟多个烛光光源
    final glowPaint = Paint()..style = PaintingStyle.fill;
    final glowPositions = [
      Offset(width * 0.2, height * 0.4),
      Offset(width * 0.5, height * 0.3),
      Offset(width * 0.8, height * 0.4),
      Offset(width * 0.35, height * 0.6),
      Offset(width * 0.65, height * 0.6),
    ];

    for (final pos in glowPositions) {
      glowPaint.shader = ui.Gradient.radial(
        pos,
        width * 0.3,
        [
          const Color(0xFFD4AF37).withOpacity(0.6),  // 金色核心
          const Color(0xFFB8860B).withOpacity(0.3),  // 暗金色
          const Color(0xFF8B6914).withOpacity(0.1),  // 过渡
          const Color(0x00000000),                   // 透明
        ],
        [0.0, 0.3, 0.6, 1.0],
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        glowPaint,
      );
    }

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  void _initScene() {
    scene = Scene();
    camera = PerspectiveCamera(
      fovRadiansY: 50 * math.pi / 180,
      fovNear: 0.1,
      fovFar: 2000.0,
    );

    // 生成背景星空
    final random = math.Random();
    for (int i = 0; i < 300; i++) {
       _stars.add(vector.Vector3(
         (random.nextDouble() - 0.5) * 2000,
         (random.nextDouble() - 0.5) * 2000,
         (random.nextDouble() - 0.5) * 2000,
       ));
    }

    // 初始化烟雾
    for (int i = 0; i < _particleCount; i++) {
        _smokeParticles.add(vector.Vector3(0, -1000, 0));
        _particleSpeeds.add(0.5 + random.nextDouble() * 0.5);
    }

    // 初始化相机姿态
    _updateCamera();

    // 尝试初始化环境和加载模型
    if (!kIsWeb) {
      Scene.initializeStaticResources().then((_) async {
         // 用代码生成纯暖金色环境贴图，确保佛像呈现金色而非透明/蓝色
         try {
           final goldEnvImage = await _createGoldenEnvironmentImage();
           final envMap = await EnvironmentMap.fromUIImages(
             radianceImage: goldEnvImage,
           );
           scene.environment.environmentMap = envMap;
           scene.environment.intensity = 2.0;
           scene.environment.exposure = 1.2;
         } catch (e) {
           debugPrint('⚠️ 自定义环境贴图生成失败，调整默认环境参数: \$e');
           scene.environment.intensity = 2.0;
           scene.environment.exposure = 1.2;
         }
         _loadModel();
      }).catchError((e) {
         debugPrint("⚠️ 渲染资源初始化失败 (需开启 Impeller 支持): \$e");
         if (mounted) setState(() => _loadFailed = true);
      });
    } else {
      debugPrint("⚠️ Web环境暂不支持 flutter_scene。");
      _loadFailed = true;
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted || !widget.isVisible) return;
    final dt = (elapsed.inMicroseconds / 1000000.0) - _lastTime;
    _lastTime = elapsed.inMicroseconds / 1000000.0;

    bool needsRepaint = false;

    // 处理自动旋转及归位
    if (!_isUserDragging) {
      if (_isAutoRotating || _isReturningToStart) {
        _rotationY -= 0.5 * dt; // 旋转速度
        
        if (_isReturningToStart) {
          double normalizedRotation = _rotationY % (2 * math.pi);
          if (normalizedRotation < 0) normalizedRotation += 2 * math.pi;
          
          if (normalizedRotation < 0.05 || normalizedRotation > (2 * math.pi - 0.05)) {
            _rotationY = 0.0;
            _isReturningToStart = false;
          }
        }
        _updateCamera();
        needsRepaint = true;
      }
    }

    // 烟雾动画更新
    if (widget.isBurning) {
      _updateSmoke(dt);
      needsRepaint = true;
    }

    // 当有状态变化时触发重绘（其实 CustomPaint 在每次 rebuild 或传入 ChangeNotifier 时都会重绘，这里我们通过 setState 驱动）
    // 为了性能，可以将 ScenePainter 包在 RepaintBoundary 中。
    if (needsRepaint) {
       setState(() {}); 
    }
  }

  void _updateCamera() {
    final x = _cameraDistance * math.sin(_rotationY);
    final z = _cameraDistance * math.cos(_rotationY);
    camera.position = vector.Vector3(x, 0.0, z);
    camera.target = vector.Vector3(0, 0, 0);
  }

  void _updateSmoke(double dt) {
    final remaining = (1.0 - _currentIncenseProgress).clamp(0.01, 1.0);
    final currentHeight = _incenseFullHeight * remaining;
    final tipPos = vector.Vector3(_incenseBaseX, _incenseBaseY + currentHeight, _incenseBaseZ);
    final time = DateTime.now().millisecondsSinceEpoch * 0.001;
    final windX = math.sin(time * 0.5) * 0.5;
    final windZ = math.cos(time * 0.3) * 0.3;

    for (int i = 0; i < _particleCount; i++) {
        var p = _smokeParticles[i];
        if (p.y > tipPos.y + 45.0 || p.y < -500) {
            p.x = tipPos.x + (math.Random().nextDouble() - 0.5) * 0.5;
            p.y = tipPos.y + (math.Random().nextDouble() * 2.0);
            p.z = tipPos.z + (math.Random().nextDouble() - 0.5) * 0.5;
        } else {
            final speed = _particleSpeeds[i];
            p.y += speed * 30.0 * dt; 
            final heightFactor = ((p.y - tipPos.y) / 45.0).clamp(0.0, 1.0);
            p.x += windX * heightFactor * 1.5 + math.sin(time * 2.0 + p.y * 0.5) * 0.1;
            p.z += windZ * heightFactor * 1.5 + math.cos(time * 1.5 + p.y * 0.5) * 0.1;
        }
    }
  }

  Future<void> _loadModel() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (mounted) setState(() { _isLoading = true; _loadFailed = false; _loadingProgress = 0.0; });
        final modelData = await AssetLoaderService.loadBuddhaModel(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
        );
        if (!mounted) return;
        
        final node = await Node.fromFlatbuffer(modelData.buffer.asByteData());
        
        // 从 .model flatbuffer 自动解析边界框并计算适配矩阵
        // 无论更换什么模型，都能自动居中和缩放
        final bounds = ModelAutoFit.computeBoundsFromModelBytes(modelData);
        node.localTransform = ModelAutoFit.computeFitTransform(bounds);
        
        scene.add(node);
        
        if (mounted) setState(() => _isLoading = false);
        return;
      } catch (e) {
        debugPrint('❌ 模型加载失败 (尝试 \$attempt): \$e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        } else {
          if (mounted) setState(() { _isLoading = false; _loadFailed = true; });
        }
      }
    }
  }

  @override
  void didUpdateWidget(BuddhaModelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRotate != widget.autoRotate) setAutoRotate(widget.autoRotate);
    if (oldWidget.isVisible != widget.isVisible) _updateVisibilityState(widget.isVisible);
    if (oldWidget.incenseProgress != widget.incenseProgress) {
       _currentIncenseProgress = widget.incenseProgress;
    }
  }

  void updateIncenseProgress(double progress) {
    _currentIncenseProgress = progress;
  }

  void _updateVisibilityState(bool isVisible) {
    if (isVisible) {
      if (!_ticker.isTicking) _ticker.start();
    } else {
      if (_ticker.isTicking) _ticker.stop();
    }
  }

  void setAutoRotate(bool enabled) {
    _isAutoRotating = enabled;
    if (!enabled) _isReturningToStart = true;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Offset? _project3DTo2D(vector.Vector3 worldPos, Size size) {
    final transform = camera.getViewTransform(size);
    final vec4 = vector.Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
    transform.transform(vec4);
    if (vec4.w <= 0.1) return null; // 位于相机后方
    final ndcX = vec4.x / vec4.w;
    final ndcY = -vec4.y / vec4.w; // 2D y 轴向下
    return Offset(
        (ndcX + 1.0) * size.width / 2.0,
        (ndcY + 1.0) * size.height / 2.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      
      // 更新经书在2D屏幕上的点击框位置
      if (!_isLoading && !_loadFailed && widget.showBook) {
        final bp = _project3DTo2D(vector.Vector3(_bookBaseX, _bookBaseY, _bookBaseZ), size);
        if (bp != null) {
          _bookScreenPos = bp;
          _bookVisibleOnScreen = true;
        } else {
          _bookVisibleOnScreen = false;
        }
      }

      return Listener(
        onPointerDown: (e) { _isUserDragging = true; _lastPointerX = e.position.dx; },
        onPointerMove: (e) {
          if (_isUserDragging && _lastPointerX != null) {
            _rotationY += (e.position.dx - _lastPointerX!) * 0.01;
            _updateCamera();
            _lastPointerX = e.position.dx;
            setState(() {});
          }
        },
        onPointerUp: (e) => _isUserDragging = false,
        onPointerCancel: (e) => _isUserDragging = false,
        child: Stack(
          children: [
            Container(color: const Color(0xFF0B0E14)),
            
            if (!_isLoading && !_loadFailed)
              CustomPaint(
                size: size,
                painter: ScenePainter(
                   scene: scene,
                   camera: camera,
                   isBurning: widget.isBurning,
                   incenseProgress: _currentIncenseProgress,
                   smokeParticles: _smokeParticles,
                   stars: _stars,
                   showBook: widget.showBook
                ),
              ),

            // 替代原 3D 经书模型的 2D HUD (利用3D反算坐标跟随视角移动)
            if (widget.showBook && widget.bookTitle != null && !_isLoading && _bookVisibleOnScreen)
              Positioned(
                 left: _bookScreenPos.dx - 60,
                 top: _bookScreenPos.dy - 30,
                 child: GestureDetector(
                   onTap: widget.onBookTap,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                     decoration: BoxDecoration(
                       gradient: const LinearGradient(
                         colors: [Color(0xD98B0000), Color(0xD95C0000)],
                         begin: Alignment.topLeft, end: Alignment.bottomRight,
                       ),
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: const Color(0x99D4AF37), width: 1.5),
                       boxShadow: const [BoxShadow(color: Color(0x33D4AF37), blurRadius: 12, spreadRadius: 1)],
                     ),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(widget.bookTitle!, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                         const SizedBox(height: 4),
                         const Text('点击阅读', style: TextStyle(color: Colors.white60, fontSize: 11)),
                       ],
                     ),
                   ),
                 ),
              ),

            // 状态 UI...
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xCC0B0E14),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFFFFD700)),
                        const SizedBox(height: 16),
                        Text('恭请佛像... ${(_loadingProgress * 100).toInt()}%', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                ),
              ),
              
            if (_loadFailed && !_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xD90B0E14),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                        const SizedBox(height: 16),
                        const Text('禅境展现遇到阻碍\\n(需Impeller及正确的.model文件)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFD700), side: const BorderSide(color: Color(0xFFFFD700))),
                          onPressed: () => _loadModel(),
                          child: const Text('静心重试'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
          ]
        )
      );
    });
  }
}

class ScenePainter extends CustomPainter {
  final Scene scene;
  final PerspectiveCamera camera;
  final bool isBurning;
  final double incenseProgress;
  final List<vector.Vector3> smokeParticles;
  final List<vector.Vector3> stars;
  final bool showBook;

  ScenePainter({
    required this.scene,
    required this.camera,
    required this.isBurning,
    required this.incenseProgress,
    required this.smokeParticles,
    required this.stars,
    required this.showBook,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 渲染 flutter_scene 的 3D 物体
    scene.render(camera, canvas);

    final transform = camera.getViewTransform(size);
    Offset? project(vector.Vector3 p) {
      final v4 = vector.Vector4(p.x, p.y, p.z, 1.0);
      transform.transform(v4);
      if (v4.w <= 0.1) return null;
      return Offset((v4.x/v4.w + 1.0) * size.width / 2.0, (-v4.y/v4.w + 1.0) * size.height / 2.0);
    }

    // --- 绘制 2D 半透明星空 ---
    final starPaint = Paint()..color = Colors.white54..strokeWidth = 1.5;
    final starPoints = <Offset>[];
    for (var s in stars) {
       final p = project(s);
       if (p != null) starPoints.add(p);
    }
    canvas.drawPoints(ui.PointMode.points, starPoints, starPaint);

    // --- 绘制 2D 香特效 ---
    final basePos = vector.Vector3(BuddhaModelScreenState._incenseBaseX, BuddhaModelScreenState._incenseBaseY, BuddhaModelScreenState._incenseBaseZ);
    final remaining = (1.0 - incenseProgress).clamp(0.01, 1.0);
    final currentHeight = BuddhaModelScreenState._incenseFullHeight * remaining;
    final tipPos = vector.Vector3(basePos.x, basePos.y + currentHeight, basePos.z);
    
    final pBase = project(basePos);
    final pTip = project(tipPos);

    if (pBase != null && pTip != null) {
      // 香柱
      final stickPaint = Paint()
        ..color = const Color(0xFF8B5A2B)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pBase, pTip, stickPaint);
      
      if (isBurning && remaining > 0.01) {
        // 燃烧头
        final tipPaint = Paint()..color = const Color(0xFFFF4500)..style = PaintingStyle.fill;
        canvas.drawCircle(pTip, 3.0, tipPaint);
        
        // 泛光效果
        final glowPaint = Paint()
          ..color = const Color(0x99FF5500)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
        canvas.drawCircle(pTip, 8.0, glowPaint);
      }
    }

    // --- 绘制烟雾粒子 ---
    if (isBurning) {
      final smokePaint = Paint()
        ..color = const Color(0x3DEEEEEE)
        ..style = PaintingStyle.fill;
      for (final particle in smokeParticles) {
        final pp = project(particle);
        if (pp != null) {
          canvas.drawCircle(pp, 2.5, smokePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
     return true; // 每帧依靠 Ticker 驱动重绘即可
  }
}
