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

enum _BuddhaRendererPath { flutterScenePrimary, androidThreeFallback }

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

  bool get _canUseAndroidThreeFallback =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _isAutoRotating = widget.autoRotate;
    _ticker = createTicker(_onTick);
    if (widget.isVisible) {
      _ticker.start();
    }
    unawaited(_bootstrapRenderer());
  }

  Future<void> _bootstrapRenderer() async {
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

  Future<void> _startAndroidThreeFallback() async {
    if (!mounted) return;
    setState(() {
      _androidThreeError = null;
      _resetForFreshLoad(
        loadingLabel: '正在安奉佛像...',
        activePath: _BuddhaRendererPath.androidThreeFallback,
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
    await _loadFlutterSceneModel(asFallback: false, reasonLabel: '正在安奉佛像...');
  }

  Future<void> _loadFlutterSceneModel({
    required bool asFallback,
    required String reasonLabel,
  }) async {
    try {
      await _ensureFlutterSceneEnvironment();
    } catch (error) {
      await _handleFlutterSceneFailure('flutter_scene 初始化失败: $error');
      return;
    }

    _scene?.removeAll();

    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      Uint8List? modelData;
      try {
        if (mounted) {
          setState(() {
            _loadingLabel = reasonLabel;
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
        debugPrint(
          '✅ [BuddhaModel] flutter_scene 模型已加载: '
          '${modelData.lengthInBytes} bytes',
        );
        AssetLoaderService.releaseBuddhaModelMemoryCache();

        setState(() {
          _isLoading = false;
          _loadFailed = false;
          _renderFailed = false;
          _flutterSceneError = null;
          _loadingProgress = 1.0;
          if (asFallback) {
            _loadingLabel = '佛像已安奉';
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

    await _handleFlutterSceneFailure(
      _flutterSceneError ?? 'flutter_scene 渲染失败',
    );
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
      scene.environment.intensity = 2.85;
      scene.environment.exposure = 1.32;
    } catch (_) {
      scene.environment.intensity = 2.35;
      scene.environment.exposure = 1.22;
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
          material.baseColorFactor = vector.Vector4(1.0, 0.92, 0.22, 1.0);
          material.metallicFactor = 0.6;
          material.roughnessFactor = 0.16;
          material.emissiveFactor = vector.Vector4(0.18, 0.12, 0.03, 1.0);
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

  Future<void> _handleFlutterSceneFailure(String details) async {
    _flutterSceneError = details;
    _lastLoadError = details;
    debugPrint('❌ [BuddhaModel] flutter_scene 失败: $details');

    if (_canUseAndroidThreeFallback) {
      await _startAndroidThreeFallback();
      return;
    }

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
    _renderFailed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_handleFlutterSceneFailure('flutter_scene 渲染失败: $error'));
    });
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

  void updateIncenseProgress(double _) {}

  void setAutoRotate(bool enabled) {
    _isAutoRotating = enabled;
    if (!enabled) {
      _isReturningToStart = true;
    }
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
                      _BuddhaRendererPath.androidThreeFallback)
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
                              unawaited(_startFlutterScenePrimary());
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
      canvas.save();
      try {
        scene.render(camera, canvas, viewport: Offset.zero & size);
      } finally {
        canvas.restore();
      }
    } catch (error) {
      onRenderError?.call(error);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => true;
}
