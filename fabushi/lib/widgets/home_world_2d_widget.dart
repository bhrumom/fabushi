import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/country_coordinates_service.dart';
import '../services/ip_location_service.dart';

class HomeWorld2DWidget extends StatefulWidget {
  const HomeWorld2DWidget({super.key});

  @override
  State<HomeWorld2DWidget> createState() => HomeWorld2DWidgetState();
}

class HomeWorld2DWidgetState extends State<HomeWorld2DWidget>
    with SingleTickerProviderStateMixin {
  static const String _landTextureAsset = 'assets/images/global_land_mask.png';
  static const String _networkDataAsset =
      'assets/data/global_network_globe.json';
  static const double _idleRotationDegreesPerSecond = 4.5;
  static const double _sendingRotationDegreesPerSecond = 1.15;
  static const Duration _targetFocusDuration = Duration(milliseconds: 2000);

  final CountryCoordinatesService _coordService = CountryCoordinatesService();
  final IPLocationService _ipLocationService = IPLocationService();
  final List<_HomeWorldBeam> _beams = <_HomeWorldBeam>[];
  final List<_NetworkNode> _networkNodes = <_NetworkNode>[];
  final List<_NetworkRoute> _networkRoutes = <_NetworkRoute>[];

  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;
  double _timeSeconds = 0;
  double _rotationLongitudeDegrees = -101;
  double? _focusStartLongitudeDegrees;
  double? _focusTargetLongitudeDegrees;
  double _focusStartSeconds = 0;
  bool _isRenderingPaused = false;
  bool _isInteractionPaused = false;
  bool _isLocationInitialized = false;

  double? _userLatitude;
  double? _userLongitude;
  String? _userCountryCode;
  String? _currentToLabel;
  ui.Image? _landTexture;
  _NetworkNode? _activeNode;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _initializeServices();
    _loadGlobeAssets();
  }

  Future<void> _initializeServices() async {
    await _coordService.initialize();
    await _initializeUserLocation();
  }

  Future<void> _loadGlobeAssets() async {
    try {
      final textureBytes = await rootBundle.load(_landTextureAsset);
      final codec = await ui.instantiateImageCodec(
        textureBytes.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();

      final rawData = await rootBundle.loadString(_networkDataAsset);
      final decoded = jsonDecode(rawData) as Map<String, dynamic>;
      final nodes = ((decoded['nodes'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_NetworkNode.fromJson)
          .toList(growable: false);
      final nodeById = {for (final node in nodes) node.id: node};
      final routes = ((decoded['routes'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => _NetworkRoute.fromJson(item, nodeById))
          .whereType<_NetworkRoute>()
          .toList(growable: false);

      if (!mounted) {
        frame.image.dispose();
        return;
      }

      setState(() {
        _landTexture?.dispose();
        _landTexture = frame.image;
        _networkNodes
          ..clear()
          ..addAll(nodes);
        _networkRoutes
          ..clear()
          ..addAll(routes);
      });
    } catch (error) {
      debugPrint('2D 首页全球网络资产加载失败: $error');
    }
  }

  Future<void> _initializeUserLocation() async {
    try {
      final location = await _ipLocationService.getCurrentLocation();
      if (!mounted) return;

      if (location != null) {
        setState(() {
          _userLatitude = location.latitude;
          _userLongitude = location.longitude;
          _userCountryCode = location.countryCode;
          _isLocationInitialized = true;
        });
        return;
      }
    } catch (error) {
      debugPrint('2D 首页定位失败: $error');
    }

    final china = _coordService.getByCountryCode('CN');
    if (!mounted || china == null) return;
    setState(() {
      _userLatitude = china.latitude;
      _userLongitude = china.longitude;
      _userCountryCode = 'CN';
      _isLocationInitialized = true;
    });
  }

  void _onTick(Duration elapsed) {
    if (_isRenderingPaused) return;
    if (elapsed - _lastFrame < const Duration(milliseconds: 33)) return;

    final previousFrame = _lastFrame;
    _lastFrame = elapsed;
    final deltaSeconds = previousFrame == Duration.zero
        ? 0.0
        : (elapsed - previousFrame).inMicroseconds /
              Duration.microsecondsPerSecond;

    if (_isInteractionPaused) {
      return;
    }

    _timeSeconds += deltaSeconds;

    _beams.removeWhere((beam) {
      final age = _timeSeconds - beam.startedAt;
      return age > beam.duration.inMilliseconds / 1000 + 1.2;
    });

    final isSending = _beams.isNotEmpty;
    final focusStart = _focusStartLongitudeDegrees;
    final focusTarget = _focusTargetLongitudeDegrees;
    if (focusStart != null && focusTarget != null) {
      final progress =
          ((_timeSeconds - _focusStartSeconds) /
                  (_targetFocusDuration.inMilliseconds / 1000))
              .clamp(0.0, 1.0)
              .toDouble();
      final eased = 1 - math.pow(1 - progress, 3).toDouble();
      _rotationLongitudeDegrees = _normalizeLongitude(
        focusStart + _shortestLongitudeDelta(focusStart, focusTarget) * eased,
      );
      if (progress >= 1) {
        _focusStartLongitudeDegrees = null;
        _focusTargetLongitudeDegrees = null;
      }
    } else {
      final speed = isSending
          ? _sendingRotationDegreesPerSecond
          : _idleRotationDegreesPerSecond;
      _rotationLongitudeDegrees = _normalizeLongitude(
        _rotationLongitudeDegrees + deltaSeconds * speed,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void addTransferBeam(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng, {
    Color? color,
    Duration? duration,
    String? fromLabel,
    String? toLabel,
  }) {
    if (!mounted) return;

    final toCountry =
        toLabel ?? _coordService.getByCoordinates(toLat, toLng)?.countryName;
    final startLat = _userLatitude ?? fromLat;
    final startLng = _userLongitude ?? fromLng;

    setState(() {
      _currentToLabel = toCountry;
      _focusStartLongitudeDegrees = _rotationLongitudeDegrees;
      _focusTargetLongitudeDegrees = _normalizeLongitude(toLng);
      _focusStartSeconds = _timeSeconds;
      _beams.add(
        _HomeWorldBeam(
          fromLat: startLat,
          fromLng: startLng,
          toLat: toLat,
          toLng: toLng,
          color: color ?? const Color(0xFFFFB653),
          duration: duration ?? const Duration(milliseconds: 1800),
          startedAt: _timeSeconds,
          toLabel: toCountry,
        ),
      );
      if (_beams.length > 8) {
        _beams.removeRange(0, _beams.length - 8);
      }
    });
  }

  void clearBeams() {
    if (!mounted) return;
    setState(() {
      _beams.clear();
      _currentToLabel = null;
      _focusStartLongitudeDegrees = null;
      _focusTargetLongitudeDegrees = null;
    });
  }

  Future<void> relocateUser() async {
    _ipLocationService.clearCache();
    await _initializeUserLocation();
  }

  String getUserLocationInfo() {
    if (!_isLocationInitialized) {
      return '位置定位中...';
    }
    if (_userCountryCode == 'CN') {
      return '中国北京';
    }
    return 'IP位置 ($_userCountryCode)';
  }

  void setRenderingPaused(bool paused) {
    if (_isRenderingPaused == paused) return;
    _isRenderingPaused = paused;
    debugPrint('2D 首页渲染暂停状态: $paused');
    if (paused) {
      _ticker.stop();
      return;
    }
    _lastFrame = Duration.zero;
    if (!_ticker.isTicking) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _landTexture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
            constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
          );

          return MouseRegion(
            cursor: _activeNode == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onHover: (event) => _updateActiveNode(event.localPosition, size),
            onExit: (_) => _clearActiveNode(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _updateActiveNode(details.localPosition, size, fromTap: true),
              child: CustomPaint(
                painter: _HomeWorld2DPainter(
                  timeSeconds: _timeSeconds,
                  rotationLongitudeDegrees: _rotationLongitudeDegrees,
                  landTexture: _landTexture,
                  beams: List<_HomeWorldBeam>.unmodifiable(_beams),
                  nodes: List<_NetworkNode>.unmodifiable(_networkNodes),
                  routes: List<_NetworkRoute>.unmodifiable(_networkRoutes),
                  activeNode: _activeNode,
                  currentToLabel: _currentToLabel,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateActiveNode(
    Offset localPosition,
    Size size, {
    bool fromTap = false,
  }) {
    final node = _findNodeAt(localPosition, size);
    if (node == _activeNode && _isInteractionPaused == (node != null)) {
      return;
    }

    setState(() {
      _activeNode = node;
      _isInteractionPaused = node != null;
    });

    if (fromTap && node == null && !_ticker.isTicking && !_isRenderingPaused) {
      _ticker.start();
    }
  }

  void _clearActiveNode() {
    if (_activeNode == null && !_isInteractionPaused) return;
    setState(() {
      _activeNode = null;
      _isInteractionPaused = false;
    });
  }

  _NetworkNode? _findNodeAt(Offset localPosition, Size size) {
    _NetworkNode? closest;
    var closestDistance = double.infinity;
    final metrics = _HomeWorldGlobeMetrics.fromSize(size);
    for (final node in _networkNodes) {
      final projected = _project(
        node.lat,
        node.lng,
        metrics.center,
        metrics.radius,
      );
      if (projected == null || projected.visibility < 0) continue;
      final distance = (projected.offset - localPosition).distance;
      final threshold = 8 + node.tier * 2.4;
      if (distance <= threshold && distance < closestDistance) {
        closest = node;
        closestDistance = distance;
      }
    }
    return closest;
  }

  _ProjectedPoint? _project(
    double lat,
    double lng,
    Offset center,
    double radius,
  ) {
    final relativeLng =
        _normalizeLongitude(lng - _rotationLongitudeDegrees) * math.pi / 180;
    final latRad = lat * math.pi / 180;
    final visibility = math.cos(latRad) * math.cos(relativeLng);
    if (visibility < -0.14) return null;

    final x = center.dx + radius * math.cos(latRad) * math.sin(relativeLng);
    final y = center.dy - radius * math.sin(latRad);
    return _ProjectedPoint(Offset(x, y), visibility);
  }

  double _normalizeLongitude(double lng) {
    return ((lng + 540) % 360) - 180;
  }

  double _shortestLongitudeDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }
}

class _HomeWorldBeam {
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final Color color;
  final Duration duration;
  final double startedAt;
  final String? toLabel;

  const _HomeWorldBeam({
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.color,
    required this.duration,
    required this.startedAt,
    this.toLabel,
  });
}

class _NetworkNode {
  final String id;
  final String country;
  final String city;
  final String continent;
  final double lat;
  final double lng;
  final int tier;

  const _NetworkNode({
    required this.id,
    required this.country,
    required this.city,
    required this.continent,
    required this.lat,
    required this.lng,
    required this.tier,
  });

  factory _NetworkNode.fromJson(Map<String, dynamic> json) {
    return _NetworkNode(
      id: (json['id'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      continent: (json['continent'] ?? '').toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      tier: math
          .max(1, math.min(3, ((json['tier'] as num?) ?? 1).toInt()))
          .toInt(),
    );
  }
}

class _NetworkRoute {
  final _NetworkNode from;
  final _NetworkNode to;

  const _NetworkRoute({required this.from, required this.to});

  static _NetworkRoute? fromJson(
    Map<String, dynamic> json,
    Map<String, _NetworkNode> nodeById,
  ) {
    final from = nodeById[(json['from'] ?? '').toString()];
    final to = nodeById[(json['to'] ?? '').toString()];
    if (from == null || to == null) return null;
    return _NetworkRoute(from: from, to: to);
  }
}

class _HomeWorldGlobeMetrics {
  final Offset center;
  final double radius;

  const _HomeWorldGlobeMetrics({required this.center, required this.radius});

  factory _HomeWorldGlobeMetrics.fromSize(Size size) {
    final radius = math
        .min(size.width * 0.72, size.height * 0.92)
        .clamp(148.0, 720.0);
    return _HomeWorldGlobeMetrics(
      center: Offset(size.width * 0.52, size.height * 0.88),
      radius: radius.toDouble(),
    );
  }
}

class _ProjectedPoint {
  final Offset offset;
  final double visibility;

  const _ProjectedPoint(this.offset, this.visibility);
}

class _HomeWorld2DPainter extends CustomPainter {
  final double timeSeconds;
  final double rotationLongitudeDegrees;
  final ui.Image? landTexture;
  final List<_HomeWorldBeam> beams;
  final List<_NetworkNode> nodes;
  final List<_NetworkRoute> routes;
  final _NetworkNode? activeNode;
  final String? currentToLabel;

  const _HomeWorld2DPainter({
    required this.timeSeconds,
    required this.rotationLongitudeDegrees,
    required this.landTexture,
    required this.beams,
    required this.nodes,
    required this.routes,
    required this.activeNode,
    required this.currentToLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final metrics = _HomeWorldGlobeMetrics.fromSize(size);
    _drawCloudflareGround(canvas, size, metrics.center, metrics.radius);
    _drawEarthSphere(canvas, metrics.center, metrics.radius);
    _drawAmbientRoutes(canvas, metrics.center, metrics.radius);
    _drawBeams(canvas, metrics.center, metrics.radius);
    _drawNodes(canvas, metrics.center, metrics.radius);
    _drawBottomFade(canvas, size);
    _drawTooltip(canvas, metrics.center, metrics.radius);
  }

  void _drawCloudflareGround(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
  ) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = uiGradientLinear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          const [Color(0xFFFFFEFA), Color(0xFFFFFCF5), Color(0xFFFFFFFF)],
        ),
    );

    canvas.drawCircle(
      center.translate(0, -radius * 0.08),
      radius * 1.1,
      Paint()
        ..color = const Color(0x2DFFB454)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );
  }

  void _drawEarthSphere(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.01,
      Paint()
        ..color = const Color(0x66F7A84B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.9),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = uiGradientRadial(
          center.translate(-radius * 0.18, -radius * 0.42),
          radius * 1.16,
          const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFCF7),
            Color(0xFFFFF2DF),
            Color(0xFFFFFBF7),
          ],
          const [0.0, 0.44, 0.78, 1.0],
        ),
    );

    final texture = landTexture;
    if (texture == null) {
      _drawFallbackLand(canvas, center, radius);
    } else {
      _drawProjectedTexture(canvas, center, radius, texture);
    }

    canvas.drawRect(
      Rect.fromCircle(center: center, radius: radius),
      Paint()
        ..shader = uiGradientRadial(
          center.translate(-radius * 0.22, -radius * 0.36),
          radius * 1.18,
          const [Color(0x22FFFFFF), Color(0x00FFFFFF), Color(0x38FFFFFF)],
          const [0.0, 0.62, 1.0],
        ),
    );
    canvas.restore();
  }

  void _drawProjectedTexture(
    Canvas canvas,
    Offset center,
    double radius,
    ui.Image texture,
  ) {
    final columns = (radius / 2.2).clamp(74.0, 192.0).round();
    final rows = (radius / 3.0).clamp(48.0, 128.0).round();
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    final texWidth = texture.width.toDouble();
    final texHeight = texture.height.toDouble();
    final cellWidth = radius * 2 / columns;
    final cellHeight = radius * 2 / rows;

    for (var col = 0; col < columns; col++) {
      final x0 = -radius + col * cellWidth;
      final x1 = x0 + cellWidth + 0.8;
      final nx0 = (x0 / radius).clamp(-1.0, 1.0).toDouble();
      final nx1 = (x1 / radius).clamp(-1.0, 1.0).toDouble();
      final midX = ((x0 + x1) / (2 * radius)).clamp(-1.0, 1.0).toDouble();
      final z = math.sqrt(math.max(0, 1 - midX * midX));
      final lon = _normalizeLongitude(
        rotationLongitudeDegrees + math.atan2(midX, z) * 180 / math.pi,
      );
      final srcX = ((lon + 180) / 360) * texWidth;
      final srcW = math.max(
        1.0,
        (math.asin(nx1) - math.asin(nx0)).abs() *
            180 /
            math.pi /
            360 *
            texWidth *
            1.22,
      );

      for (var row = 0; row < rows; row++) {
        final y0 = -radius + row * cellHeight;
        final y1 = y0 + cellHeight + 0.8;
        final midY = ((y0 + y1) / (2 * radius)).clamp(-1.0, 1.0).toDouble();
        if (midX * midX + midY * midY > 1.025) continue;

        final lat =
            math.asin((-midY).clamp(-1.0, 1.0).toDouble()) * 180 / math.pi;
        final srcY = ((90 - lat) / 180) * texHeight;
        final srcH = math.max(
          1.0,
          cellHeight / (radius * 2) * texHeight * 1.12,
        );

        _drawWrappedImageRect(
          canvas,
          texture,
          Rect.fromLTWH(srcX - srcW / 2, srcY - srcH / 2, srcW, srcH),
          Rect.fromLTWH(center.dx + x0, center.dy + y0, x1 - x0, y1 - y0),
          paint,
        );
      }
    }
  }

  void _drawWrappedImageRect(
    Canvas canvas,
    ui.Image texture,
    Rect src,
    Rect dst,
    Paint paint,
  ) {
    final texWidth = texture.width.toDouble();
    final texHeight = texture.height.toDouble();
    final top = src.top.clamp(0.0, texHeight - 1).toDouble();
    final height = src.height.clamp(1.0, texHeight - top).toDouble();
    var left = src.left % texWidth;
    if (left < 0) left += texWidth;

    if (left + src.width <= texWidth) {
      canvas.drawImageRect(
        texture,
        Rect.fromLTWH(
          left,
          top,
          src.width.clamp(1.0, texWidth).toDouble(),
          height,
        ),
        dst,
        paint,
      );
      return;
    }

    final firstWidth = texWidth - left;
    final firstRatio = firstWidth / src.width;
    canvas.drawImageRect(
      texture,
      Rect.fromLTWH(left, top, firstWidth, height),
      Rect.fromLTWH(dst.left, dst.top, dst.width * firstRatio, dst.height),
      paint,
    );
    canvas.drawImageRect(
      texture,
      Rect.fromLTWH(0, top, src.width - firstWidth, height),
      Rect.fromLTWH(
        dst.left + dst.width * firstRatio,
        dst.top,
        dst.width * (1 - firstRatio),
        dst.height,
      ),
      paint,
    );
  }

  void _drawFallbackLand(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()
        ..color = const Color(0x77F78E35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  void _drawAmbientRoutes(Canvas canvas, Offset center, double radius) {
    if (routes.isEmpty) return;
    final visibleRoutes = routes.take(16).toList(growable: false);
    for (var i = 0; i < visibleRoutes.length; i++) {
      final route = visibleRoutes[i];
      final start = _project(route.from.lat, route.from.lng, center, radius);
      final end = _project(route.to.lat, route.to.lng, center, radius);
      if (start == null || end == null) continue;
      if (start.visibility < -0.02 || end.visibility < -0.02) continue;
      final phase = (timeSeconds * 0.13 + i * 0.087) % 1.0;
      _drawRoutePath(
        canvas,
        start.offset,
        end.offset,
        radius,
        progress: phase,
        color: const Color(0xFFFFB653),
        subtle: true,
      );
    }
  }

  void _drawBeams(Canvas canvas, Offset center, double radius) {
    for (final beam in beams) {
      final age = timeSeconds - beam.startedAt;
      final durationSeconds = beam.duration.inMilliseconds / 1000;
      final progress = (age / durationSeconds).clamp(0.0, 1.0).toDouble();
      if (progress <= 0) continue;

      final start = _project(beam.fromLat, beam.fromLng, center, radius);
      final end = _project(beam.toLat, beam.toLng, center, radius);
      if (start == null || end == null) continue;
      _drawRoutePath(
        canvas,
        start.offset,
        end.offset,
        radius,
        progress: progress,
        color: beam.color,
        subtle: false,
      );

      if (beam.toLabel != null && progress > 0.82) {
        _drawSmallLabel(canvas, beam.toLabel!, end.offset);
      }
    }
  }

  void _drawRoutePath(
    Canvas canvas,
    Offset start,
    Offset end,
    double radius, {
    required double progress,
    required Color color,
    required bool subtle,
  }) {
    final control = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - radius * (subtle ? 0.14 : 0.22),
    );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: subtle ? 0.18 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = subtle ? 0.8 : 1.2
        ..strokeCap = StrokeCap.round,
    );

    final head = _quadraticPoint(start, control, end, progress);
    final tail = _quadraticPoint(
      start,
      control,
      end,
      (progress - (subtle ? 0.12 : 0.18)).clamp(0.0, 1.0).toDouble(),
    );
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..shader = uiGradientLinear(tail, head, [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: subtle ? 0.48 : 0.82),
          Colors.white.withValues(alpha: subtle ? 0.7 : 1.0),
        ])
        ..style = PaintingStyle.stroke
        ..strokeWidth = subtle ? 1.6 : 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawNodes(Canvas canvas, Offset center, double radius) {
    for (final node in nodes) {
      final projected = _project(node.lat, node.lng, center, radius);
      if (projected == null || projected.visibility < -0.02) continue;
      final isActive = node == activeNode;
      final baseRadius = 1.25 + node.tier * 0.72;
      final nodeRadius = isActive ? baseRadius + 2.0 : baseRadius;
      final alpha = (0.38 + projected.visibility * 0.62).clamp(0.0, 1.0);

      canvas.drawCircle(
        projected.offset,
        nodeRadius + 3.2,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        projected.offset,
        nodeRadius,
        Paint()
          ..color =
              (isActive ? const Color(0xFF243E62) : const Color(0xFF536783))
                  .withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        projected.offset,
        nodeRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75,
      );
    }
  }

  void _drawTooltip(Canvas canvas, Offset center, double radius) {
    final node = activeNode;
    if (node == null) return;
    final projected = _project(node.lat, node.lng, center, radius);
    if (projected == null || projected.visibility < -0.02) return;

    final title = node.city.isEmpty ? node.country : node.city;
    final subtitle = node.city.isEmpty
        ? '${node.continent} · 全球节点'
        : '${node.country} · ${node.continent}';
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 150);
    final subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 170);
    final statusPainter = TextPainter(
      text: const TextSpan(
        text: '节点在线',
        style: TextStyle(
          color: Color(0xFFF78E35),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 170);

    final boxWidth =
        math.max(
          titlePainter.width,
          math.max(subtitlePainter.width, statusPainter.width),
        ) +
        24;
    final boxHeight = 64.0;
    var left = projected.offset.dx - boxWidth / 2;
    final top = projected.offset.dy - boxHeight - 14;
    left = left.clamp(8.0, center.dx + radius - boxWidth - 8).toDouble();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xF7FFFFFF));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0x33F78E35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    titlePainter.paint(canvas, Offset(left + 12, top + 8));
    subtitlePainter.paint(canvas, Offset(left + 12, top + 27));
    statusPainter.paint(canvas, Offset(left + 12, top + 45));
  }

  void _drawSmallLabel(Canvas canvas, String label, Offset anchor) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Colors.white, blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 96);
    painter.paint(canvas, anchor.translate(-painter.width / 2, 10));
  }

  void _drawBottomFade(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.38),
      Paint()
        ..shader = uiGradientLinear(
          Offset(0, size.height * 0.62),
          Offset(0, size.height),
          const [Color(0x00FFFFFF), Color(0xCCFFFFFF), Color(0xFFFFFFFF)],
        ),
    );
  }

  _ProjectedPoint? _project(
    double lat,
    double lng,
    Offset center,
    double radius,
  ) {
    final relativeLng =
        _normalizeLongitude(lng - rotationLongitudeDegrees) * math.pi / 180;
    final latRad = lat * math.pi / 180;
    final visibility = math.cos(latRad) * math.cos(relativeLng);
    if (visibility < -0.14) return null;

    final x = center.dx + radius * math.cos(latRad) * math.sin(relativeLng);
    final y = center.dy - radius * math.sin(latRad);
    return _ProjectedPoint(Offset(x, y), visibility);
  }

  Offset _quadraticPoint(Offset a, Offset b, Offset c, double t) {
    final oneMinus = 1 - t;
    return Offset(
      oneMinus * oneMinus * a.dx + 2 * oneMinus * t * b.dx + t * t * c.dx,
      oneMinus * oneMinus * a.dy + 2 * oneMinus * t * b.dy + t * t * c.dy,
    );
  }

  double _normalizeLongitude(double lng) {
    return ((lng + 540) % 360) - 180;
  }

  @override
  bool shouldRepaint(covariant _HomeWorld2DPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.rotationLongitudeDegrees != rotationLongitudeDegrees ||
        oldDelegate.landTexture != landTexture ||
        oldDelegate.beams != beams ||
        oldDelegate.nodes != nodes ||
        oldDelegate.routes != routes ||
        oldDelegate.activeNode != activeNode ||
        oldDelegate.currentToLabel != currentToLabel;
  }
}

ui.Shader uiGradientRadial(
  Offset center,
  double radius,
  List<Color> colors, [
  List<double>? stops,
]) {
  return RadialGradient(
    colors: colors,
    stops: stops,
  ).createShader(Rect.fromCircle(center: center, radius: radius));
}

ui.Shader uiGradientLinear(Offset start, Offset end, List<Color> colors) {
  return LinearGradient(
    colors: colors,
  ).createShader(Rect.fromPoints(start, end));
}
