import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;

import '../core/config/app_config.dart';

class AndroidThreeBuddhaView extends StatefulWidget {
  final double rotationY;
  final bool isVisible;
  final ValueChanged<double>? onProgress;
  final VoidCallback? onReady;
  final ValueChanged<String>? onError;

  const AndroidThreeBuddhaView({
    super.key,
    required this.rotationY,
    required this.isVisible,
    this.onProgress,
    this.onReady,
    this.onError,
  });

  @override
  State<AndroidThreeBuddhaView> createState() => _AndroidThreeBuddhaViewState();
}

class _AndroidThreeBuddhaViewState extends State<AndroidThreeBuddhaView> {
  static const Duration _initDelay = Duration(milliseconds: 100);
  static const Duration _modelLoadTimeout = Duration(seconds: 90);

  FlutterGlPlugin? _glPlugin;
  three.WebGLRenderer? _renderer;
  three.WebGLRenderTarget? _renderTarget;
  dynamic _sourceTexture;

  three.Scene? _scene;
  three.PerspectiveCamera? _camera;

  bool _initializing = false;
  bool _ready = false;
  bool _failed = false;
  bool _disposed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        if (_canInitialize(size)) {
          _scheduleInitialize(size, dpr);
        }

        final textureId = _glPlugin?.textureId;
        if (textureId == null || _glPlugin?.isInitialized != true) {
          return const SizedBox.expand();
        }

        return SizedBox.expand(child: Texture(textureId: textureId));
      },
    );
  }

  bool _canInitialize(Size size) {
    return !_initializing &&
        !_ready &&
        !_failed &&
        !_disposed &&
        size.width.isFinite &&
        size.height.isFinite &&
        size.width > 0 &&
        size.height > 0;
  }

  void _scheduleInitialize(Size size, double dpr) {
    _initializing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      unawaited(_initialize(size, dpr));
    });
  }

  Future<void> _initialize(Size size, double dpr) async {
    final plugin = FlutterGlPlugin();
    try {
      await plugin.initialize(
        options: {
          'antialias': true,
          'alpha': true,
          'width': size.width.round(),
          'height': size.height.round(),
          'dpr': dpr,
        },
      );

      if (!mounted || _disposed) {
        plugin.dispose();
        return;
      }

      setState(() {
        _glPlugin = plugin;
      });

      await Future<void>.delayed(_initDelay);
      await plugin.prepareContext();

      if (!mounted || _disposed) {
        plugin.dispose();
        return;
      }

      _initRenderer(plugin, size, dpr);
      _initScene(size);
      widget.onProgress?.call(0.24);

      final model = await _loadBuddhaModel();
      if (!mounted || _disposed) return;

      _fitAndRetuneModel(model);
      _scene!.add(model);
      _updateCamera();

      _ready = true;
      _initializing = false;
      widget.onProgress?.call(1.0);
      widget.onReady?.call();

      if (mounted) {
        setState(() {});
      }
      _render();
    } catch (error) {
      _initializing = false;
      plugin.dispose();
      _fail('Android three_dart 初始化失败: $error');
    }
  }

  void _initRenderer(FlutterGlPlugin plugin, Size size, double dpr) {
    final options = {
      'width': size.width,
      'height': size.height,
      'gl': plugin.gl,
      'antialias': true,
      'alpha': true,
      'canvas': plugin.element,
      'logarithmicDepthBuffer': true,
    };

    final renderer = three.WebGLRenderer(options);
    renderer.setPixelRatio(dpr);
    renderer.setSize(size.width, size.height, false);
    renderer.shadowMap.enabled = false;
    renderer.outputEncoding = three.LinearEncoding;
    renderer.toneMapping = three.NoToneMapping;
    renderer.toneMappingExposure = 1.0;
    renderer.setClearColor(three.Color(0x000000), 0.0);

    final renderTargetOptions = three.WebGLRenderTargetOptions({
      'minFilter': three.LinearFilter,
      'magFilter': three.LinearFilter,
      'format': three.RGBAFormat,
    });
    final renderTarget = three.WebGLRenderTarget(
      (size.width * dpr).round(),
      (size.height * dpr).round(),
      renderTargetOptions,
    );
    renderTarget.samples = 4;
    renderer.setRenderTarget(renderTarget);

    _renderer = renderer;
    _renderTarget = renderTarget;
    _sourceTexture = renderer.getRenderTargetGLTexture(renderTarget);
  }

  void _initScene(Size size) {
    final scene = three.Scene();
    final camera = three.PerspectiveCamera(
      45,
      size.width / size.height,
      0.1,
      10000,
    );
    camera.position.set(0, 120, 290);

    final ambientLight = three.AmbientLight(0xffffff, 1.1);
    scene.add(ambientLight);

    final keyLight = three.DirectionalLight(0xffd05b, 1.8);
    keyLight.position.set(80, 200, 120);
    scene.add(keyLight);

    final fillLight = three.PointLight(0xffe7aa, 1.1, 620);
    fillLight.position.set(-120, 110, 90);
    scene.add(fillLight);

    final rimLight = three.PointLight(0x8b5a16, 0.9, 520);
    rimLight.position.set(0, 40, -180);
    scene.add(rimLight);

    _scene = scene;
    _camera = camera;
  }

  Future<three.Object3D> _loadBuddhaModel() async {
    try {
      final bytes = await _loadBundledGlbBytes();
      widget.onProgress?.call(0.58);
      return _parseGlbBytes(bytes);
    } catch (error) {
      debugPrint(
        '⚠️ [BuddhaModel][three_dart] bundled GLB 加载失败，尝试远端 GLB: $error',
      );
    }

    widget.onProgress?.call(0.32);
    final loader = three_jsm.GLTFLoader();
    final result = await loader
        .loadAsync(AppConfig.legacyBuddhaGlbUrl)
        .timeout(_modelLoadTimeout);
    return _extractScene(result);
  }

  Future<Uint8List> _loadBundledGlbBytes() async {
    final data = await rootBundle.load(
      AppConfig.androidThreeBuddhaGlbAssetPath,
    );
    final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    if (!_isGlb(bytes)) {
      throw StateError('bundled GLB 不是有效 glTF binary: ${_formatHeader(bytes)}');
    }
    if (bytes.lengthInBytes < AppConfig.minBuddhaGlbSizeBytes) {
      throw StateError('bundled GLB 体积异常: ${bytes.lengthInBytes} bytes');
    }
    return bytes;
  }

  Future<three.Object3D> _parseGlbBytes(Uint8List bytes) async {
    final completer = Completer<dynamic>();
    final loader = three_jsm.GLTFLoader();
    loader.parse(
      bytes,
      '',
      (gltf) {
        if (!completer.isCompleted) completer.complete(gltf);
      },
      (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
    final result = await completer.future.timeout(_modelLoadTimeout);
    return _extractScene(result);
  }

  three.Object3D _extractScene(dynamic gltf) {
    final scene = gltf is Map ? gltf['scene'] : null;
    if (scene is three.Object3D) {
      return scene;
    }
    throw StateError('GLB 未返回有效 scene');
  }

  void _fitAndRetuneModel(three.Object3D model) {
    final bounds = three.Box3().setFromObject(model);
    final size = three.Vector3();
    final center = three.Vector3();
    bounds.getSize(size);
    bounds.getCenter(center);

    final maxAxis = math.max(size.x, math.max(size.y, size.z));
    if (maxAxis > 0 && maxAxis.isFinite) {
      final scale = 170.0 / maxAxis;
      model.scale.setScalar(scale);
      model.position.sub(center.multiplyScalar(scale));
    }

    model.position.y += 18;
    model.rotation.y = math.pi;
    model.rotation.x = 0.08;

    model.traverse((child) {
      if (child is! three.Mesh) return;
      child.castShadow = false;
      child.receiveShadow = false;
      child.material = _createBuddhaMaterial(child.material);
    });
  }

  dynamic _createBuddhaMaterial(dynamic material) {
    if (material is Iterable) {
      return material.map(_createBuddhaMaterial).toList();
    }

    final simpleMaterial = three.MeshBasicMaterial({
      'color': three.Color.fromHex(0xffcc4a),
      'fog': false,
      'toneMapped': false,
    });
    if (material is three.Material && material.transparent == true) {
      simpleMaterial.transparent = true;
      simpleMaterial.opacity = material.opacity;
    }
    return simpleMaterial;
  }

  void _updateCamera() {
    final camera = _camera;
    if (camera == null) return;

    final x = 290.0 * math.sin(widget.rotationY);
    final z = 290.0 * math.cos(widget.rotationY);
    camera.position.set(x, 120.0, z);
    camera.lookAt(three.Vector3(0, 90, 0));
  }

  void _render() {
    if (!_ready || !widget.isVisible || _disposed) return;

    final plugin = _glPlugin;
    final renderer = _renderer;
    final scene = _scene;
    final camera = _camera;
    if (plugin == null || renderer == null || scene == null || camera == null) {
      return;
    }

    try {
      renderer.render(scene, camera);
      plugin.gl.flush();
      if (!kIsWeb && _sourceTexture != null) {
        unawaited(plugin.updateTexture(_sourceTexture));
      }
    } catch (error) {
      _fail('Android three_dart 渲染失败: $error');
    }
  }

  void _fail(String message) {
    if (_failed || _disposed) return;
    _failed = true;
    _ready = false;
    debugPrint('❌ [BuddhaModel][three_dart] $message');
    widget.onError?.call(message);
    if (mounted) setState(() {});
  }

  static bool _isGlb(Uint8List bytes) {
    return bytes.lengthInBytes >= 12 &&
        bytes[0] == 0x67 &&
        bytes[1] == 0x6C &&
        bytes[2] == 0x54 &&
        bytes[3] == 0x46;
  }

  static String _formatHeader(Uint8List bytes) {
    if (bytes.isEmpty) return '<empty>';
    return bytes
        .take(math.min(12, bytes.lengthInBytes))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  @override
  void didUpdateWidget(covariant AndroidThreeBuddhaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationY != widget.rotationY ||
        oldWidget.isVisible != widget.isVisible) {
      _updateCamera();
      _render();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _glPlugin?.dispose();
    _renderTarget?.dispose();
    _scene = null;
    _camera = null;
    super.dispose();
  }
}
