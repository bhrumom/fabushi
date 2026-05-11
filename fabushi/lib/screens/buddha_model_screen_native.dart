import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
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

class BuddhaModelScreenState extends State<BuddhaModelScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late Scene scene;
  late PerspectiveCamera camera;
  late Ticker _ticker;
  double _lastTime = 0.0;

  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _loadFailed = false;
  bool _renderFailed = false;

  double _rotationY = 0.0;
  final double _cameraDistance = 250.0;
  bool _isUserDragging = false;
  double? _lastPointerX;
  bool _isReturningToStart = false;
  bool _isAutoRotating = false;
  double _currentIncenseProgress = 0.0;
  final math.Random _random = math.Random();

  // 香和书的基准位置 (3D 坐标)
  static const double _incenseBaseX = 0.0;
  static const double _incenseBaseY = -60.0;
  static const double _incenseBaseZ = 80.0;
  static const double _incenseFullHeight = 46.0;
  static const List<double> _incenseStickOffsets = [-7.0, 0.0, 7.0];

  // 烟雾粒子
  final int _particleCount = 90;
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
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // 反射环境保持暖金，不把蓝色背景直接喂给金属材质。
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF4F3200),
    );

    // 上方主光：明亮金黄，但不发白。
    final topLightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width * 0.5, height * 0.18),
        width * 0.48,
        const [
          Color(0xFFFFF0B8),
          Color(0xFFFFD43B),
          Color(0xC8B97800),
          Color(0x00000000),
        ],
        const [0.0, 0.24, 0.62, 1.0],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      topLightPaint,
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
          const Color(0xFFFFEE9A).withValues(alpha: 0.90), // 高亮核心
          const Color(0xFFFFC800).withValues(alpha: 0.58), // 金黄过渡
          const Color(0xFFC98D00).withValues(alpha: 0.22), // 饱和金边
          const Color(0x00000000), // 透明
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
      _stars.add(
        vector.Vector3(
          (random.nextDouble() - 0.5) * 2000,
          (random.nextDouble() - 0.5) * 2000,
          (random.nextDouble() - 0.5) * 2000,
        ),
      );
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
      Scene.initializeStaticResources()
          .then((_) async {
            // 用代码生成纯暖金色环境贴图，确保佛像呈现金色而非透明/蓝色
            try {
              final goldEnvImage = await _createGoldenEnvironmentImage();
              final envMap = await EnvironmentMap.fromUIImages(
                radianceImage: goldEnvImage,
                irradianceImage: goldEnvImage,
              );
              scene.environment.environmentMap = envMap;
              scene.environment.intensity = 2.0;
              scene.environment.exposure = 1.12;
            } catch (e) {
              debugPrint('⚠️ 自定义环境贴图生成失败，调整默认环境参数: \$e');
              scene.environment.intensity = 1.75;
              scene.environment.exposure = 1.05;
            }
            _loadModel();
          })
          .catchError((e) {
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
    final now = elapsed.inMicroseconds / 1000000.0;
    final dt = _lastTime == 0.0 ? 0.0 : (now - _lastTime).clamp(0.0, 1 / 30);
    _lastTime = now;

    bool needsRepaint = false;

    // 处理自动旋转及归位
    if (!_isUserDragging) {
      if (_isAutoRotating || _isReturningToStart) {
        _rotationY -= 0.5 * dt; // 旋转速度

        if (_isReturningToStart) {
          double normalizedRotation = _rotationY % (2 * math.pi);
          if (normalizedRotation < 0) normalizedRotation += 2 * math.pi;

          if (normalizedRotation < 0.05 ||
              normalizedRotation > (2 * math.pi - 0.05)) {
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
    final remaining = (1.0 - _currentIncenseProgress)
        .clamp(0.01, 1.0)
        .toDouble();
    final currentHeight = _incenseFullHeight * remaining;
    final time = DateTime.now().millisecondsSinceEpoch * 0.001;
    final windX = math.sin(time * 0.48) * 0.72;
    final windZ = math.cos(time * 0.34) * 0.42;

    for (int i = 0; i < _particleCount; i++) {
      var p = _smokeParticles[i];
      final sourceOffset =
          _incenseStickOffsets[i % _incenseStickOffsets.length];
      final tipPos = vector.Vector3(
        _incenseBaseX + sourceOffset,
        _incenseBaseY + currentHeight,
        _incenseBaseZ + (i % 3 - 1) * 0.8,
      );

      if (p.y > tipPos.y + 86.0 || p.y < -500) {
        p.x = tipPos.x + (_random.nextDouble() - 0.5) * 1.6;
        p.y = tipPos.y + (_random.nextDouble() * 2.0);
        p.z = tipPos.z + (_random.nextDouble() - 0.5) * 1.4;
      } else {
        final speed = _particleSpeeds[i];
        p.y += speed * 34.0 * dt;
        final heightFactor = ((p.y - tipPos.y) / 86.0)
            .clamp(0.0, 1.0)
            .toDouble();
        p.x +=
            (windX * heightFactor * 1.35 +
                math.sin(time * 1.8 + i * 0.37 + p.y * 0.12) * 0.85) *
            dt;
        p.z +=
            (windZ * heightFactor +
                math.cos(time * 1.25 + i * 0.31 + p.y * 0.1) * 0.55) *
            dt;
      }
    }
  }

  void _retuneBuddhaMaterials(Node node) {
    final mesh = node.mesh;
    if (mesh != null) {
      for (final MeshPrimitive primitive in mesh.primitives) {
        final material = primitive.material;
        if (material is PhysicallyBasedMaterial) {
          material.baseColorFactor = vector.Vector4(1.0, 0.86, 0.08, 1.0);
          material.metallicFactor = 0.68;
          material.roughnessFactor = 0.18;
          material.emissiveFactor = vector.Vector4(0.10, 0.07, 0.012, 1.0);
          material.vertexColorWeight = 0.0;
        }
      }
    }

    for (final child in node.children) {
      _retuneBuddhaMaterials(child);
    }
  }

  Future<void> _loadModel() async {
    const maxRetries = 3;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
        _loadingProgress = 0.0;
      });
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      var modelDataLoaded = false;
      try {
        final modelData = await AssetLoaderService.loadBuddhaModel(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
        );
        modelDataLoaded = true;
        if (!mounted) return;

        await _buildBuddhaNode(modelData);

        if (mounted) {
          setState(() {
            _isLoading = false;
            _renderFailed = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('❌ 模型加载失败 (尝试 $attempt): $e');
        if (modelDataLoaded) {
          await AssetLoaderService.evictBuddhaModelCache();
        }
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        } else {
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

  Future<void> _buildBuddhaNode(Uint8List modelData) async {
    final node = await Node.fromFlatbuffer(modelData.buffer.asByteData());
    _retuneBuddhaMaterials(node);

    // 从 .model flatbuffer 自动解析边界框并计算适配矩阵
    // 无论更换什么模型，都能自动居中和缩放
    final bounds = ModelAutoFit.computeBoundsFromModelBytes(modelData);
    final originalTransform = node.localTransform.clone();
    node.localTransform = ModelAutoFit.computeFitTransform(
      bounds,
      originalTransform: originalTransform,
    );

    scene.add(node);
  }

  @override
  void didUpdateWidget(BuddhaModelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRotate != widget.autoRotate) {
      setAutoRotate(widget.autoRotate);
    }
    if (oldWidget.isVisible != widget.isVisible) {
      _updateVisibilityState(widget.isVisible);
    }
    if (oldWidget.incenseProgress != widget.incenseProgress) {
      _currentIncenseProgress = widget.incenseProgress;
    }
  }

  void updateIncenseProgress(double progress) {
    _currentIncenseProgress = progress;
    if (mounted) setState(() {});
  }

  void _updateVisibilityState(bool isVisible) {
    if (isVisible) {
      _lastTime = 0.0;
      if (!_ticker.isTicking && !_renderFailed) _ticker.start();
    } else {
      if (_ticker.isTicking) _ticker.stop();
    }
  }

  void _handleRenderFailure(Object error) {
    if (_renderFailed || !mounted) return;
    debugPrint('❌ [BuddhaModel] 场景渲染失败: $error');
    _ticker.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _renderFailed = true;
        _loadFailed = true;
      });
    });
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          onPointerDown: (e) {
            _isUserDragging = true;
            _lastPointerX = e.position.dx;
          },
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
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1A2864),
                      Color(0xFF111C48),
                      Color(0xFF090E22),
                    ],
                  ),
                ),
                child: SizedBox.expand(),
              ),

              if (!_isLoading && !_loadFailed)
                ClipRect(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: size,
                      painter: ScenePainter(
                        scene: scene,
                        camera: camera,
                        isBurning: widget.isBurning,
                        incenseProgress: _currentIncenseProgress,
                        smokeParticles: _smokeParticles,
                        stars: _stars,
                        showBook: widget.showBook,
                        onRenderError: _handleRenderFailure,
                      ),
                    ),
                  ),
                ),

              if (!_isLoading && !_loadFailed)
                IgnorePointer(
                  child: CustomPaint(
                    size: size,
                    painter: _IncensePainter(
                      isBurning: widget.isBurning,
                      incenseProgress: _currentIncenseProgress,
                    ),
                  ),
                ),

              // 经书固定摆在佛像正前方，不随模型旋转漂移。
              if (widget.showBook && widget.bookTitle != null && !_isLoading)
                Positioned(
                  left: (size.width - 184) / 2,
                  top: (size.height * 0.54)
                      .clamp(0.0, size.height - 270)
                      .toDouble(),
                  child: _SutraBookButton(
                    title: widget.bookTitle!,
                    onTap: widget.onBookTap,
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
                          const CircularProgressIndicator(
                            color: Color(0xFFFFD700),
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

              if (_loadFailed && !_isLoading)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xD90B0E14),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white54,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '禅境展现遇到阻碍\\n(需Impeller及正确的.model文件)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFD700),
                              side: const BorderSide(color: Color(0xFFFFD700)),
                            ),
                            onPressed: () => _loadModel(),
                            child: const Text('静心重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SutraBookButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _SutraBookButton({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: title,
        child: SizedBox(
          width: 184,
          height: 128,
          child: CustomPaint(painter: _SutraBookPainter(title)),
        ),
      ),
    );
  }
}

class _SutraBookPainter extends CustomPainter {
  final String title;

  _SutraBookPainter(this.title);

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0x99000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.82),
        width: size.width * 0.78,
        height: 20,
      ),
      shadowPaint,
    );

    final pagePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.26, size.height * 0.2),
        Offset(size.width * 0.74, size.height * 0.72),
        const [Color(0xFFFFF3C6), Color(0xFFE4C26F), Color(0xFF7A4A16)],
        const [0.0, 0.54, 1.0],
      );
    final coverPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.2, size.height * 0.12),
        Offset(size.width * 0.82, size.height * 0.7),
        const [Color(0xFF9E1C16), Color(0xFF5E0707), Color(0xFF2A0202)],
        const [0.0, 0.5, 1.0],
      );
    final rightCoverPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.46, size.height * 0.1),
        Offset(size.width * 0.9, size.height * 0.66),
        const [Color(0xFFC0261E), Color(0xFF6B0808), Color(0xFF310303)],
        const [0.0, 0.5, 1.0],
      );

    final leftPages = Path()
      ..moveTo(size.width * 0.15, size.height * 0.32)
      ..lineTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.5, size.height * 0.78)
      ..lineTo(size.width * 0.14, size.height * 0.68)
      ..close();
    final rightPages = Path()
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.88, size.height * 0.32)
      ..lineTo(size.width * 0.86, size.height * 0.68)
      ..lineTo(size.width * 0.5, size.height * 0.78)
      ..close();

    canvas.drawPath(leftPages, pagePaint);
    canvas.drawPath(rightPages, pagePaint);

    final leftCover = Path()
      ..moveTo(size.width * 0.09, size.height * 0.24)
      ..lineTo(size.width * 0.49, size.height * 0.09)
      ..lineTo(size.width * 0.5, size.height * 0.72)
      ..lineTo(size.width * 0.1, size.height * 0.59)
      ..close();
    final rightCover = Path()
      ..moveTo(size.width * 0.51, size.height * 0.09)
      ..lineTo(size.width * 0.93, size.height * 0.25)
      ..lineTo(size.width * 0.9, size.height * 0.6)
      ..lineTo(size.width * 0.5, size.height * 0.72)
      ..close();
    canvas.drawPath(leftCover, coverPaint);
    canvas.drawPath(rightCover, rightCoverPaint);

    final goldLine = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(leftCover, goldLine);
    canvas.drawPath(rightCover, goldLine);
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.74),
      Paint()
        ..color = const Color(0xAA3A1204)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.12),
      Offset(size.width * 0.5, size.height * 0.71),
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    final pageLine = Paint()
      ..color = const Color(0x887A4A16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.34 + i * 0.065);
      canvas.drawLine(
        Offset(size.width * 0.2, y + i * 1.5),
        Offset(size.width * 0.43, y - 8),
        pageLine,
      );
      canvas.drawLine(
        Offset(size.width * 0.57, y - 8),
        Offset(size.width * 0.82, y + i * 1.4),
        pageLine,
      );
    }

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFFFFE6A3),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          shadows: [Shadow(color: Color(0xFF3A1204), blurRadius: 4)],
          height: 1.2,
        ),
      ),
      maxLines: 2,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    );
    titlePainter.layout(maxWidth: size.width * 0.82);
    final offsetY = titlePainter.height > 20
        ? size.height * 0.31
        : size.height * 0.37;
    titlePainter.paint(
      canvas,
      Offset((size.width - titlePainter.width) / 2, offsetY),
    );

    final hintPainter = TextPainter(
      text: const TextSpan(
        text: '经卷',
        style: TextStyle(color: Color(0xCCFFF4C2), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    hintPainter.layout();
    hintPainter.paint(
      canvas,
      Offset((size.width - hintPainter.width) / 2, size.height * 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _SutraBookPainter oldDelegate) {
    return title != oldDelegate.title;
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
  final ValueChanged<Object>? onRenderError;

  ScenePainter({
    required this.scene,
    required this.camera,
    required this.isBurning,
    required this.incenseProgress,
    required this.smokeParticles,
    required this.stars,
    required this.showBook,
    this.onRenderError,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
      return;
    }

    // 显式限制 3D 场景的渲染视口，避免 flutter_scene 从无限 clip bounds 推导出异常纹理尺寸。
    try {
      scene.render(camera, canvas, viewport: Offset.zero & size);
    } catch (error) {
      onRenderError?.call(error);
      return;
    }

    final transform = camera.getViewTransform(size);
    Offset? project(vector.Vector3 p) {
      final v4 = vector.Vector4(p.x, p.y, p.z, 1.0);
      transform.transform(v4);
      if (v4.w <= 0.1) return null;
      return Offset(
        (v4.x / v4.w + 1.0) * size.width / 2.0,
        (-v4.y / v4.w + 1.0) * size.height / 2.0,
      );
    }

    // --- 绘制 2D 半透明星空 ---
    final starPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5;
    final starPoints = <Offset>[];
    for (var s in stars) {
      final p = project(s);
      if (p != null) starPoints.add(p);
    }
    canvas.drawPoints(ui.PointMode.points, starPoints, starPaint);
    _drawOfferingSets(canvas, size);
  }

  void _drawOfferingSets(Canvas canvas, Size size) {
    final y = size.height * 0.79;
    final spread = (size.width * 0.25).clamp(96.0, 156.0).toDouble();
    _drawOfferingSet(canvas, Offset(size.width / 2 - spread, y), mirror: false);
    _drawOfferingSet(canvas, Offset(size.width / 2 + spread, y), mirror: true);
  }

  void _drawOfferingSet(Canvas canvas, Offset center, {required bool mirror}) {
    final scale = mirror ? -1.0 : 1.0;
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 30), width: 106, height: 18),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 22), width: 94, height: 20),
        const Radius.circular(10),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          center.translate(-44, 14),
          center.translate(44, 36),
          const [Color(0xFFFFD36A), Color(0xFF7A4314), Color(0xFFD4AF37)],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 12), width: 82, height: 18),
      Paint()..color = const Color(0xAA2B1306),
    );

    _drawOfferingLamp(canvas, center.translate(scale * 34, -18));
    _drawOfferingFlowers(canvas, center.translate(scale * -18, -18));
    _drawOfferingFruit(canvas, center.translate(scale * 7, 0));
  }

  void _drawOfferingLamp(Canvas canvas, Offset center) {
    for (var i = 2; i >= 0; i--) {
      canvas.drawCircle(
        center.translate(0, -12),
        15.0 + i * 9,
        Paint()
          ..color = Color.lerp(
            const Color(0x33FFF2A8),
            const Color(0x00FF8A24),
            i / 2,
          )!
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + i * 4),
      );
    }
    final flame = Path()
      ..moveTo(center.dx, center.dy - 30)
      ..cubicTo(center.dx + 11, center.dy - 19, center.dx + 6, center.dy - 7, center.dx, center.dy - 4)
      ..cubicTo(center.dx - 8, center.dy - 10, center.dx - 8, center.dy - 21, center.dx, center.dy - 30)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = ui.Gradient.radial(
          center.translate(0, -16),
          20,
          const [Color(0xFFFFF5B7), Color(0xFFFF8A24), Color(0x00FF8A24)],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 2), width: 30, height: 12),
      Paint()..color = const Color(0xFFD4AF37),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 11), width: 22, height: 20),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF74420F),
    );
  }

  void _drawOfferingFlowers(Canvas canvas, Offset center) {
    final stemPaint = Paint()
      ..color = const Color(0xFF426A2B)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final dx in const [-10.0, 0.0, 10.0]) {
      canvas.drawLine(center.translate(dx * 0.25, 14), center.translate(dx, -18), stemPaint);
      for (var i = 0; i < 6; i++) {
        canvas.save();
        canvas.translate(center.dx + dx, center.dy - 20);
        canvas.rotate(i * math.pi / 3);
        canvas.drawOval(
          const Rect.fromLTWH(-4, -11, 8, 13),
          Paint()..color = const Color(0xFFEBA7C8),
        );
        canvas.restore();
      }
      canvas.drawCircle(center.translate(dx, -20), 3.5, Paint()..color = const Color(0xFFFFE16A));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 16), width: 26, height: 18),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF7B3E19),
    );
  }

  void _drawOfferingFruit(Canvas canvas, Offset center) {
    final fruits = <MapEntry<Offset, Color>>[
      const MapEntry(Offset(-12, 2), Color(0xFFFFC34D)),
      const MapEntry(Offset(0, -7), Color(0xFFD83A2E)),
      const MapEntry(Offset(13, 3), Color(0xFFFFB13B)),
    ];
    for (final fruit in fruits) {
      canvas.drawCircle(center + fruit.key, 10, Paint()..color = fruit.value);
      canvas.drawCircle(
        center + fruit.key.translate(-3, -3),
        3,
        Paint()..color = const Color(0x66FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return true; // 每帧依靠 Ticker 驱动重绘即可
  }
}

class _IncensePainter extends CustomPainter {
  final double incenseProgress;
  final bool isBurning;

  _IncensePainter({required this.incenseProgress, required this.isBurning});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    _drawFixedIncense(canvas, size);
  }

  void _drawFixedIncense(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.82);
    final remaining = (1.0 - incenseProgress).clamp(0.16, 1.0).toDouble();
    final stickHeight = 74.0 * remaining;
    _drawIncenseBurner(canvas, base, stickHeight);

    for (final offset in const [-14.0, 0.0, 14.0]) {
      final stickBase = base.translate(offset, 6);
      final stickTip = stickBase.translate(0, -stickHeight - 14);
      canvas.drawLine(
        stickBase,
        stickTip,
        Paint()
          ..shader = ui.Gradient.linear(
            stickBase,
            stickTip,
            const [Color(0xFF5A2E16), Color(0xFFB07136), Color(0xFF2B1509)],
            const [0.0, 0.5, 1.0],
          )
          ..strokeWidth = 3.3
          ..strokeCap = StrokeCap.round,
      );

      if (isBurning) {
        canvas.drawCircle(
          stickTip,
          6,
          Paint()
            ..shader = ui.Gradient.radial(
              stickTip,
              8,
              const [Color(0xFFFFF1A3), Color(0xFFFF6B1A), Color(0x00FF6B1A)],
              const [0.0, 0.5, 1.0],
            ),
        );
        canvas.drawCircle(
          stickTip,
          2.4,
          Paint()..color = const Color(0xFFFFE6A3),
        );
        _drawFixedSmoke(canvas, stickTip, offset);
      }
    }
  }

  void _drawFixedSmoke(Canvas canvas, Offset tip, double seed) {
    final time = DateTime.now().millisecondsSinceEpoch * 0.001;
    for (var i = 0; i < 11; i++) {
      final t = (time * 0.18 + i / 11 + seed * 0.006) % 1.0;
      final x = tip.dx + math.sin(t * math.pi * 2.0 + seed) * (7 + t * 26);
      final y = tip.dy - t * 122 - i * 3.2;
      final radius = 2.4 + t * 9.5;
      final opacity = ((1 - t) * 0.45 + 0.05).clamp(0.0, 0.5).toDouble();
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.fromRGBO(235, 229, 214, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + t * 5),
      );

      if (i.isEven) {
        final wisp = Path()
          ..moveTo(x, y + radius)
          ..quadraticBezierTo(
            x + math.sin(time + i) * 10,
            y - radius * 1.6,
            x + math.cos(time * 0.7 + i) * 18,
            y - radius * 3.2,
          );
        canvas.drawPath(
          wisp,
          Paint()
            ..color = Color.fromRGBO(242, 236, 220, opacity * 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 + t * 1.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }
    }
  }

  void _drawIncenseBurner(Canvas canvas, Offset center, double stickHeight) {
    final width = (stickHeight * 1.22).clamp(48.0, 88.0).toDouble();
    final topHeight = (stickHeight * 0.22).clamp(10.0, 16.0).toDouble();
    final bodyHeight = (stickHeight * 0.45).clamp(20.0, 34.0).toDouble();
    final topCenter = center.translate(0, 8);

    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter.translate(0, bodyHeight * 0.72),
        width: width * 0.92,
        height: topHeight,
      ),
      shadowPaint,
    );

    final body = Path()
      ..moveTo(topCenter.dx - width * 0.48, topCenter.dy)
      ..quadraticBezierTo(
        topCenter.dx - width * 0.38,
        topCenter.dy + bodyHeight,
        topCenter.dx,
        topCenter.dy + bodyHeight * 1.12,
      )
      ..quadraticBezierTo(
        topCenter.dx + width * 0.38,
        topCenter.dy + bodyHeight,
        topCenter.dx + width * 0.48,
        topCenter.dy,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(topCenter.dx - width * 0.5, topCenter.dy),
          Offset(topCenter.dx + width * 0.5, topCenter.dy + bodyHeight),
          const [Color(0xFF4A2111), Color(0xFF9A5A24), Color(0xFF2A1208)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0x99D4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final rimRect = Rect.fromCenter(
      center: topCenter,
      width: width,
      height: topHeight,
    );
    canvas.drawOval(
      rimRect,
      Paint()
        ..shader = ui.Gradient.linear(
          rimRect.topLeft,
          rimRect.bottomRight,
          const [Color(0xFFD4AF37), Color(0xFF6F3514), Color(0xFFFFD36A)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter,
        width: width * 0.78,
        height: topHeight * 0.58,
      ),
      Paint()..color = const Color(0xFF25110A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: topCenter.translate(0, 1),
        width: width * 0.64,
        height: topHeight * 0.36,
      ),
      Paint()..color = const Color(0xFF6A5A45),
    );
  }

  @override
  bool shouldRepaint(covariant _IncensePainter oldDelegate) {
    return true;
  }
}
