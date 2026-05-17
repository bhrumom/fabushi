import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vector;

import '../services/asset_loader_service.dart';
import '../utils/model_auto_fit.dart';
import 'buddha_model_screen_android_three.dart';

enum _BuddhaRendererPath { androidThreePrimary, flutterScenePrimary }

class BuddhaModelScreen extends StatefulWidget {
  final bool autoRotate;
  final bool isBurning;
  final double incenseProgress;
  final bool showBook;
  final String? bookTitle;
  final VoidCallback? onBookTap;
  final bool isVisible;

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
  late final Ticker _ticker;

  Scene? _scene;
  PerspectiveCamera? _camera;
  double _lastTime = 0.0;

  bool _isLoading = true;
  bool _loadFailed = false;
  bool _renderFailed = false;
  double _loadingProgress = 0.0;
  double _rotationY = 0.0;
  double _currentIncenseProgress = 0.0;
  final double _cameraDistance = 250.0;

  bool _isUserDragging = false;
  double? _lastPointerX;
  bool _isReturningToStart = false;
  bool _isAutoRotating = false;

  _BuddhaRendererPath? _activeRendererPath;

  String? _lastLoadError;
  String? _androidThreeError;
  String? _flutterSceneError;
  String _loadingLabel = '恭请佛像...';

  bool get _shouldUseAndroidThreePrimary =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _isAutoRotating = widget.autoRotate;
    _currentIncenseProgress = widget.incenseProgress;
    _ticker = createTicker(_onTick);
    if (widget.isVisible) {
      _ticker.start();
    }
    unawaited(_bootstrapRenderer());
  }

  Future<void> _bootstrapRenderer() async {
    if (_shouldUseAndroidThreePrimary) {
      await _startAndroidThreePrimary();
      return;
    }
    await _startFlutterScenePrimary();
  }

  void _resetForFreshLoad({
    required String loadingLabel,
    _BuddhaRendererPath? activePath,
  }) {
    _lastLoadError = null;
    _renderFailed = false;
    _loadFailed = false;
    _isLoading = true;
    _loadingProgress = 0.0;
    _loadingLabel = loadingLabel;
    _activeRendererPath = activePath;
    if (widget.isVisible && !_ticker.isTicking) {
      _lastTime = 0.0;
      _ticker.start();
    }
  }

  Future<void> _startAndroidThreePrimary() async {
    if (!mounted) return;
    setState(() {
      _flutterSceneError = null;
      _androidThreeError = null;
      _resetForFreshLoad(
        loadingLabel: '安卓佛像加载中...',
        activePath: _BuddhaRendererPath.androidThreePrimary,
      );
    });
  }

  Future<void> _startFlutterScenePrimary() async {
    if (!mounted) return;
    setState(() {
      _flutterSceneError = null;
      _androidThreeError = null;
      _resetForFreshLoad(
        loadingLabel: '恭请佛像...',
        activePath: _BuddhaRendererPath.flutterScenePrimary,
      );
    });
    await _loadFlutterSceneModel(
      asFallback: false,
      reasonLabel: 'flutter_scene 渲染准备中...',
    );
  }

  Future<void> _loadFlutterSceneModel({
    required bool asFallback,
    required String reasonLabel,
  }) async {
    try {
      await _ensureFlutterSceneEnvironment();
    } catch (error) {
      _markFlutterSceneFailed('flutter_scene 初始化失败: $error');
      return;
    }

    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      Uint8List? modelData;
      try {
        if (mounted) {
          setState(() {
            _loadingLabel = attempt == 1
                ? reasonLabel
                : '$reasonLabel（重试 $attempt/$maxRetries）';
          });
        }

        modelData = await AssetLoaderService.loadBuddhaModel(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress;
            });
          },
        );

        if (!mounted) return;
        await _buildBuddhaNode(modelData);
        AssetLoaderService.releaseBuddhaModelMemoryCache();

        setState(() {
          _isLoading = false;
          _loadFailed = false;
          _renderFailed = false;
          _flutterSceneError = null;
          _loadingProgress = 1.0;
          if (asFallback) {
            _loadingLabel = '已切换 flutter_scene 备用展示';
          }
        });
        return;
      } catch (error) {
        _flutterSceneError = 'flutter_scene 解析失败: $error';
        _lastLoadError = _flutterSceneError;
        AssetLoaderService.releaseBuddhaModelMemoryCache();
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 << attempt));
          continue;
        }
      }
    }

    _markFlutterSceneFailed(_flutterSceneError ?? 'flutter_scene 备用渲染失败');
  }

  Future<void> _ensureFlutterSceneEnvironment() async {
    if (_scene != null && _camera != null) {
      return;
    }

    final scene = Scene();
    final camera = PerspectiveCamera(
      fovRadiansY: 50 * math.pi / 180,
      fovNear: 0.1,
      fovFar: 2000.0,
    );
    _scene = scene;
    _camera = camera;
    _updateCamera();

    await Scene.initializeStaticResources();

    try {
      final goldEnvImage = await _createGoldenEnvironmentImage();
      final envMap = await EnvironmentMap.fromUIImages(
        radianceImage: goldEnvImage,
        irradianceImage: goldEnvImage,
      );
      scene.environment.environmentMap = envMap;
      scene.environment.intensity = 2.0;
      scene.environment.exposure = 1.12;
    } catch (_) {
      scene.environment.intensity = 1.75;
      scene.environment.exposure = 1.05;
    }
  }

  Future<void> _buildBuddhaNode(Uint8List modelData) async {
    final scene = _scene;
    if (scene == null) {
      throw StateError('flutter_scene 尚未初始化');
    }

    final bounds = ModelAutoFit.computeBoundsFromModelBytes(modelData);
    final node = await Node.fromFlatbuffer(ByteData.sublistView(modelData));
    _retuneBuddhaMaterials(node);

    final originalTransform = node.localTransform.clone();
    node.localTransform = ModelAutoFit.computeFitTransform(
      bounds,
      originalTransform: originalTransform,
    );

    scene.add(node);
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

  static Future<ui.Image> _createGoldenEnvironmentImage() async {
    const int width = 256;
    const int height = 128;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF4F3200),
    );

    final lightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width * 0.5, height * 0.2),
        width * 0.46,
        const [Color(0xFFFFF0B8), Color(0xFFFFD43B), Color(0x00000000)],
        const [0.0, 0.35, 1.0],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      lightPaint,
    );

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  void _markAndroidThreeReady() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadFailed = false;
      _renderFailed = false;
      _loadingProgress = 1.0;
    });
  }

  void _handleAndroidThreeFailure(String details) {
    _androidThreeError = details;
    _lastLoadError = details;
    debugPrint('❌ [BuddhaModel] Android three_dart 失败: $details');
    _markLoadFailed(details);
  }

  void _markFlutterSceneFailed(String details) {
    _flutterSceneError = details;
    _lastLoadError = details;
    debugPrint('❌ [BuddhaModel] flutter_scene 失败: $details');
    _markLoadFailed(details);
  }

  void _markLoadFailed(String details) {
    if (_ticker.isTicking) {
      _ticker.stop();
    }
    if (!mounted) return;
    setState(() {
      _loadFailed = true;
      _renderFailed = true;
      _isLoading = false;
    });
  }

  String _cleanLoadError(String error) {
    final compact = error
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();
    if (compact.length <= 260) {
      return compact;
    }
    return '${compact.substring(0, 257)}...';
  }

  String get _loadFailureDetails {
    final details = <String>[];
    if (_androidThreeError != null && _androidThreeError!.isNotEmpty) {
      details.add('Android Three：${_cleanLoadError(_androidThreeError!)}');
    }
    if (_flutterSceneError != null && _flutterSceneError!.isNotEmpty) {
      details.add('flutter_scene：${_cleanLoadError(_flutterSceneError!)}');
    }
    if (details.isEmpty &&
        _lastLoadError != null &&
        _lastLoadError!.isNotEmpty) {
      details.add(_cleanLoadError(_lastLoadError!));
    }
    if (details.isEmpty) {
      return '未收到具体错误，请重试后查看设备日志。';
    }
    return details.join('\n');
  }

  void _onTick(Duration elapsed) {
    if (!mounted || !widget.isVisible) {
      return;
    }
    final now = elapsed.inMicroseconds / 1000000.0;
    final dt = _lastTime == 0.0 ? 0.0 : (now - _lastTime).clamp(0.0, 1 / 30);
    _lastTime = now;

    if (!_isUserDragging && (_isAutoRotating || _isReturningToStart)) {
      _rotationY -= 0.5 * dt;
      if (_isReturningToStart) {
        double normalizedRotation = _rotationY % (2 * math.pi);
        if (normalizedRotation < 0) normalizedRotation += 2 * math.pi;
        if (normalizedRotation < 0.05 ||
            normalizedRotation > (2 * math.pi - 0.05)) {
          _rotationY = 0.0;
          _isReturningToStart = false;
        }
      }
      if (_activeRendererPath == _BuddhaRendererPath.flutterScenePrimary) {
        _updateCamera();
      }
      setState(() {});
    }
  }

  void _updateCamera() {
    final camera = _camera;
    if (camera == null) {
      return;
    }
    final x = _cameraDistance * math.sin(_rotationY);
    final z = _cameraDistance * math.cos(_rotationY);
    camera.position = vector.Vector3(x, 0.0, z);
    camera.target = vector.Vector3(0, 0, 0);
  }

  void _handleRenderFailure(Object error) {
    if (_renderFailed || !mounted) {
      return;
    }
    _markFlutterSceneFailed('flutter_scene 渲染失败: $error');
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

  void _updateVisibilityState(bool isVisible) {
    if (isVisible) {
      _lastTime = 0.0;
      if (!_ticker.isTicking && !_renderFailed) {
        _ticker.start();
      }
    } else if (_ticker.isTicking) {
      _ticker.stop();
    }
  }

  void updateIncenseProgress(double progress) {
    _currentIncenseProgress = progress;
    if (mounted) {
      setState(() {});
    }
  }

  void setAutoRotate(bool enabled) {
    _isAutoRotating = enabled;
    if (!enabled) {
      _isReturningToStart = true;
    }
  }

  String get _compatibilityBanner {
    if (_activeRendererPath == _BuddhaRendererPath.androidThreePrimary) {
      return '安卓佛像使用 three_dart 原生渲染';
    }
    return '佛像已切换为兼容展示';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final scene = _scene;
        final camera = _camera;

        return Listener(
          onPointerDown: (event) {
            _isUserDragging = true;
            _lastPointerX = event.position.dx;
          },
          onPointerMove: (event) {
            if (_isUserDragging && _lastPointerX != null) {
              _rotationY += (event.position.dx - _lastPointerX!) * 0.01;
              _lastPointerX = event.position.dx;
              if (_activeRendererPath ==
                  _BuddhaRendererPath.flutterScenePrimary) {
                _updateCamera();
              }
              setState(() {});
            }
          },
          onPointerUp: (_) => _isUserDragging = false,
          onPointerCancel: (_) => _isUserDragging = false,
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
              if (!_loadFailed &&
                  _activeRendererPath ==
                      _BuddhaRendererPath.androidThreePrimary)
                Positioned.fill(
                  child: AndroidThreeBuddhaView(
                    key: ValueKey(
                      'android-three-${_loadFailed ? 'failed' : 'active'}',
                    ),
                    rotationY: _rotationY,
                    isVisible: widget.isVisible,
                    onProgress: (progress) {
                      if (!mounted) return;
                      setState(() {
                        _loadingProgress = progress;
                      });
                    },
                    onReady: _markAndroidThreeReady,
                    onError: _handleAndroidThreeFailure,
                  ),
                )
              else if (!_isLoading &&
                  !_loadFailed &&
                  scene != null &&
                  camera != null)
                Positioned.fill(
                  child: CustomPaint(
                    size: size,
                    painter: _ScenePainter(
                      scene: scene,
                      camera: camera,
                      onRenderError: _handleRenderFailure,
                    ),
                  ),
                ),
              if (!_isLoading && !_loadFailed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: size,
                      painter: _IncensePainter(
                        incenseProgress: _currentIncenseProgress,
                        isBurning: widget.isBurning,
                      ),
                    ),
                  ),
                ),
              if (!_isLoading &&
                  !_loadFailed &&
                  _activeRendererPath !=
                      _BuddhaRendererPath.flutterScenePrimary)
                Positioned(
                  top: 18,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFD4AF37,
                            ).withValues(alpha: 0.36),
                          ),
                        ),
                        child: Text(
                          _compatibilityBanner,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.showBook && widget.bookTitle != null && !_isLoading)
                Positioned(
                  left: (size.width - 184) / 2,
                  top: (size.height * 0.58)
                      .clamp(0.0, size.height - 180)
                      .toDouble(),
                  child: _SutraBookButton(
                    title: widget.bookTitle!,
                    onTap: widget.onBookTap,
                  ),
                ),
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
                            _loadingLabel,
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 14,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (_loadingProgress > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${(_loadingProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
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
                            '禅境展现遇到阻碍',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Text(
                              _loadFailureDetails,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFD700),
                              side: const BorderSide(color: Color(0xFFFFD700)),
                            ),
                            onPressed: () {
                              if (_shouldUseAndroidThreePrimary) {
                                unawaited(_startAndroidThreePrimary());
                              } else {
                                unawaited(_startFlutterScenePrimary());
                              }
                            },
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

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class _ScenePainter extends CustomPainter {
  final Scene scene;
  final PerspectiveCamera camera;
  final ValueChanged<Object>? onRenderError;

  const _ScenePainter({
    required this.scene,
    required this.camera,
    this.onRenderError,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
      return;
    }

    try {
      scene.render(camera, canvas, viewport: Offset.zero & size);
    } catch (error) {
      onRenderError?.call(error);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => true;
}

class _SutraBookButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _SutraBookButton({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: SizedBox(
        width: 184,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xAA5E0707),
            foregroundColor: const Color(0xFFFFE6A3),
            side: const BorderSide(color: Color(0xFFD4AF37)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '经卷',
                style: TextStyle(fontSize: 11, color: Color(0xCCFFF4C2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncensePainter extends CustomPainter {
  final double incenseProgress;
  final bool isBurning;

  const _IncensePainter({
    required this.incenseProgress,
    required this.isBurning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
      return;
    }

    final base = Offset(size.width / 2, size.height * 0.82);
    final remaining = (1.0 - incenseProgress).clamp(0.16, 1.0).toDouble();
    final stickHeight = 74.0 * remaining;

    canvas.drawOval(
      Rect.fromCenter(center: base.translate(0, 36), width: 108, height: 20),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: base.translate(0, 22), width: 92, height: 22),
        const Radius.circular(10),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          base.translate(-46, 12),
          base.translate(46, 34),
          const [Color(0xFFFFD36A), Color(0xFF7A4314), Color(0xFFD4AF37)],
        ),
    );

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

      if (!isBurning) {
        continue;
      }

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

      for (var i = 0; i < 9; i++) {
        final t =
            ((DateTime.now().millisecondsSinceEpoch / 1000) * 0.2 +
                i / 9 +
                offset * 0.006) %
            1.0;
        final smokeCenter = Offset(
          stickTip.dx + math.sin(t * math.pi * 2.0 + offset) * (7 + t * 24),
          stickTip.dy - t * 118 - i * 3.0,
        );
        canvas.drawCircle(
          smokeCenter,
          2.4 + t * 9.0,
          Paint()
            ..color = Color.fromRGBO(
              235,
              229,
              214,
              ((1 - t) * 0.45 + 0.05).clamp(0.0, 0.5),
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + t * 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IncensePainter oldDelegate) => true;
}
