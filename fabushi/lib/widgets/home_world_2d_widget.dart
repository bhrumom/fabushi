import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' hide Image, LinearGradient, RadialGradient;

import '../services/country_coordinates_service.dart';
import '../services/ip_location_service.dart';

class HomeWorld2DWidget extends StatefulWidget {
  const HomeWorld2DWidget({super.key});

  @override
  State<HomeWorld2DWidget> createState() => HomeWorld2DWidgetState();
}

class HomeWorld2DWidgetState extends State<HomeWorld2DWidget>
    with SingleTickerProviderStateMixin {
  static const String _riveOrbitAsset = 'assets/rive/home_world_orbit.riv';
  static const String _riveStateMachineName = 'HomeWorldOrbit';
  static const double _idleRotationDegreesPerSecond = 4.5;
  static const double _sendingRotationDegreesPerSecond = 1.15;
  static const Duration _targetFocusDuration = Duration(milliseconds: 2000);

  final CountryCoordinatesService _coordService = CountryCoordinatesService();
  final IPLocationService _ipLocationService = IPLocationService();
  final List<_HomeWorldBeam> _beams = <_HomeWorldBeam>[];

  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;
  double _timeSeconds = 0;
  double _rotationLongitudeDegrees = 108;
  double? _focusStartLongitudeDegrees;
  double? _focusTargetLongitudeDegrees;
  double _focusStartSeconds = 0;
  bool _isRenderingPaused = false;
  bool _isLocationInitialized = false;
  bool _riveAssetAvailable = false;

  double? _userLatitude;
  double? _userLongitude;
  String? _userCountryCode;
  String? _currentToLabel;
  ui.Image? _earthTexture;
  SMIBool? _riveIsSending;
  SMINumber? _rivePulse;
  SMINumber? _riveRotationSpeed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _checkRiveAsset();
    _initializeServices();
  }

  Future<void> _checkRiveAsset() async {
    try {
      await rootBundle.load(_riveOrbitAsset);
      if (!mounted) return;
      setState(() => _riveAssetAvailable = true);
    } catch (error) {
      debugPrint('2D 首页 Rive 资产不可用，使用 Flutter 地球投影层渲染: $error');
    }
  }

  Future<void> _initializeServices() async {
    await _coordService.initialize();
    await _initializeUserLocation();
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
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final deltaSeconds = previousFrame == Duration.zero
        ? 0.0
        : (elapsed - previousFrame).inMicroseconds /
              Duration.microsecondsPerSecond;

    _beams.removeWhere((beam) {
      final age = seconds - beam.startedAt;
      return age > beam.duration.inMilliseconds / 1000 + 1.2;
    });

    final isSending = _beams.isNotEmpty;
    final focusStart = _focusStartLongitudeDegrees;
    final focusTarget = _focusTargetLongitudeDegrees;
    if (focusStart != null && focusTarget != null) {
      final progress =
          ((seconds - _focusStartSeconds) /
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

    _syncRiveInputs(isSending: isSending);

    if (mounted) {
      setState(() => _timeSeconds = seconds);
    }
  }

  void _syncRiveInputs({required bool isSending}) {
    _riveIsSending?.value = isSending;
    _rivePulse?.value = (0.5 + math.sin(_timeSeconds * 1.8) * 0.5)
        .clamp(0.0, 1.0)
        .toDouble();
    _riveRotationSpeed?.value = isSending
        ? _sendingRotationDegreesPerSecond
        : _idleRotationDegreesPerSecond;
  }

  void _onRiveInit(Artboard artboard) {
    try {
      final controller = StateMachineController.fromArtboard(
        artboard,
        _riveStateMachineName,
      );
      if (controller == null) {
        debugPrint('2D 首页 Rive 未找到状态机: $_riveStateMachineName');
        return;
      }
      artboard.addController(controller);
      _riveIsSending = controller.findInput<bool>('isSending') as SMIBool?;
      _rivePulse = controller.findInput<double>('pulse') as SMINumber?;
      _riveRotationSpeed =
          controller.findInput<double>('rotationSpeed') as SMINumber?;
      _syncRiveInputs(isSending: _beams.isNotEmpty);
    } catch (error) {
      debugPrint('2D 首页 Rive 状态机初始化失败: $error');
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
          color: color ?? const Color(0xFFFFD76B),
          duration: duration ?? const Duration(milliseconds: 1800),
          startedAt: _timeSeconds,
          toLabel: toCountry,
        ),
      );
      if (_beams.length > 8) {
        _beams.removeRange(0, _beams.length - 8);
      }
    });
    _syncRiveInputs(isSending: true);
  }

  void clearBeams() {
    if (!mounted) return;
    setState(() {
      _beams.clear();
      _currentToLabel = null;
      _focusStartLongitudeDegrees = null;
      _focusTargetLongitudeDegrees = null;
    });
    _syncRiveInputs(isSending: false);
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
    debugPrint('🌏 2D 首页渲染暂停状态: $paused');
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
    _earthTexture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home_world_lightfield.webp',
            fit: BoxFit.cover,
          ),
          if (_riveAssetAvailable)
            RiveAnimation.asset(
              _riveOrbitAsset,
              fit: BoxFit.cover,
              onInit: _onRiveInit,
            ),
          CustomPaint(
            painter: _HomeWorld2DPainter(
              timeSeconds: _timeSeconds,
              rotationLongitudeDegrees: _rotationLongitudeDegrees,
              earthTexture: _earthTexture,
              beams: List<_HomeWorldBeam>.unmodifiable(_beams),
              currentToLabel: _currentToLabel,
            ),
          ),
        ],
      ),
    );
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

class _HomeWorld2DPainter extends CustomPainter {
  final double timeSeconds;
  final double rotationLongitudeDegrees;
  final ui.Image? earthTexture;
  final List<_HomeWorldBeam> beams;
  final String? currentToLabel;

  const _HomeWorld2DPainter({
    required this.timeSeconds,
    required this.rotationLongitudeDegrees,
    required this.earthTexture,
    required this.beams,
    required this.currentToLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final globeCenter = Offset(size.width / 2, size.height * 0.34);
    final globeRadius = (math.min(size.width, size.height) * 0.34)
        .clamp(122.0, 260.0)
        .toDouble();

    _drawAtmosphere(canvas, size, globeCenter, globeRadius);
    _drawEarthSphere(canvas, globeCenter, globeRadius);
    _drawBeams(canvas, globeCenter, globeRadius);
    _drawBottomGlow(canvas, size);
  }

  void _drawAtmosphere(Canvas canvas, Size size, Offset center, double radius) {
    final pulse = 0.5 + math.sin(timeSeconds * 1.2) * 0.5;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (center.dx / size.width) * 2 - 1,
            (center.dy / size.height) * 2 - 1,
          ),
          radius: 0.82,
          colors: [
            Color.lerp(
              const Color(0x55FFFFFF),
              const Color(0x88FFE9A3),
              pulse,
            )!,
            const Color(0x00000000),
          ],
        ).createShader(Offset.zero & size),
    );

    for (var i = 0; i < 18; i++) {
      final phase = timeSeconds * 0.08 + i * 0.37;
      final x = (math.sin(phase * 1.7) * 0.5 + 0.5) * size.width;
      final y = (math.cos(phase * 1.1) * 0.5 + 0.5) * size.height * 0.58;
      final opacity = 0.12 + (math.sin(phase * 2.3) * 0.5 + 0.5) * 0.18;
      canvas.drawCircle(
        Offset(x, y),
        1.2 + (i % 4) * 0.8,
        Paint()
          ..color = Color.fromRGBO(255, 246, 196, opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  void _drawEarthSphere(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.08,
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    final texture = earthTexture;
    if (texture == null) {
      _drawTextureFallback(canvas, center, radius);
    } else {
      _drawProjectedTexture(canvas, center, radius, texture);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = uiGradientRadial(
          center.translate(-radius * 0.28, -radius * 0.22),
          radius * 1.18,
          const [
            Color(0x55FFFFFF),
            Color(0x113FE7E0),
            Color(0x66111F4A),
            Color(0x99040A18),
          ],
          const [0.0, 0.35, 0.78, 1.0],
        ),
    );
    canvas.restore();

    final ringPaint = Paint()
      ..color = const Color(0xCCFFF2A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(center, radius, ringPaint);

    final gridPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final scaleY in const [0.22, 0.42, 0.62]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 1.72,
          height: radius * 2 * scaleY,
        ),
        gridPaint,
      );
    }
    for (final offset in const [-0.46, -0.22, 0.0, 0.22, 0.46]) {
      final path = Path()
        ..moveTo(center.dx + radius * offset, center.dy - radius * 0.96)
        ..cubicTo(
          center.dx + radius * offset * 1.9,
          center.dy - radius * 0.42,
          center.dx + radius * offset * 1.9,
          center.dy + radius * 0.42,
          center.dx + radius * offset,
          center.dy + radius * 0.96,
        );
      canvas.drawPath(path, gridPaint);
    }
  }

  void _drawTextureFallback(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = uiGradientRadial(
          center.translate(-radius * 0.18, -radius * 0.22),
          radius * 1.18,
          const [Color(0xFF9FE8FF), Color(0xFF2BA7CE), Color(0xFF174B7A)],
          const [0, 0.62, 1],
        ),
    );
    _drawPainterlyContinents(canvas, center, radius);
    _drawSoftCloudBands(canvas, center, radius);
  }

  void _drawPainterlyContinents(Canvas canvas, Offset center, double radius) {
    final landPaint = Paint()
      ..color = const Color(0xCCF8D88A)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
    final shadowPaint = Paint()
      ..color = const Color(0x554B812E)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);

    const continents = <List<(double, double)>>[
      [(54, -132), (64, -96), (48, -62), (25, -80), (14, -106), (30, -132)],
      [(12, -82), (4, -62), (-18, -58), (-52, -70), (-32, -45), (-4, -78)],
      [(70, -12), (62, 58), (36, 92), (8, 76), (4, 30), (28, -8)],
      [(34, 70), (24, 112), (2, 122), (-9, 96), (8, 78)],
      [(31, -10), (18, 30), (-30, 26), (-36, 12), (-4, -12)],
      [(-12, 112), (-22, 148), (-44, 146), (-38, 114)],
    ];

    for (final polygon in continents) {
      final points = polygon
          .map((point) => _project(point.$1, point.$2, center, radius))
          .whereType<Offset>()
          .toList();
      if (points.length < 3) continue;

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final current = points[i];
        final previous = points[i - 1];
        path.quadraticBezierTo(
          previous.dx,
          previous.dy,
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
      }
      path.close();
      canvas.drawPath(path.shift(const Offset(0, 1.6)), shadowPaint);
      canvas.drawPath(path, landPaint);
    }
  }

  void _drawSoftCloudBands(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.035
      ..shader = uiGradientLinear(
        center.translate(-radius, 0),
        center.translate(radius, 0),
        const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var i = 0; i < 4; i++) {
      final y = center.dy + radius * (-0.42 + i * 0.26);
      final phase = timeSeconds * 0.28 + i * 1.7;
      final path = Path()
        ..moveTo(center.dx - radius * 0.82, y + math.sin(phase) * radius * 0.03)
        ..cubicTo(
          center.dx - radius * 0.34,
          y - radius * (0.08 + i * 0.012),
          center.dx + radius * 0.34,
          y + radius * (0.08 - i * 0.01),
          center.dx + radius * 0.82,
          y + math.cos(phase) * radius * 0.03,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _drawProjectedTexture(
    Canvas canvas,
    Offset center,
    double radius,
    ui.Image texture,
  ) {
    final columns = (radius / 3.2).clamp(44.0, 96.0).round();
    final rows = (radius / 4.0).clamp(32.0, 72.0).round();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final texWidth = texture.width.toDouble();
    final texHeight = texture.height.toDouble();
    final cellWidth = radius * 2 / columns;
    final cellHeight = radius * 2 / rows;

    for (var col = 0; col < columns; col++) {
      final x0 = -radius + col * cellWidth;
      final x1 = x0 + cellWidth + 0.75;
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
            1.35,
      );

      for (var row = 0; row < rows; row++) {
        final y0 = -radius + row * cellHeight;
        final y1 = y0 + cellHeight + 0.75;
        final midY = ((y0 + y1) / (2 * radius)).clamp(-1.0, 1.0).toDouble();
        if (midX * midX + midY * midY > 1.02) continue;

        final lat =
            math.asin((-midY).clamp(-1.0, 1.0).toDouble()) * 180 / math.pi;
        final srcY = ((90 - lat) / 180) * texHeight;
        final srcH = math.max(
          1.0,
          cellHeight / (radius * 2) * texHeight * 1.15,
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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = uiGradientRadial(
          center.translate(-radius * 0.36, -radius * 0.28),
          radius * 1.32,
          const [Color(0x44FFFFFF), Color(0x00000000), Color(0x6607132F)],
          const [0, 0.46, 1],
        ),
    );
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

  void _drawBeams(Canvas canvas, Offset center, double radius) {
    for (final beam in beams) {
      final age = timeSeconds - beam.startedAt;
      final durationSeconds = beam.duration.inMilliseconds / 1000;
      final progress = (age / durationSeconds).clamp(0.0, 1.0).toDouble();
      if (progress <= 0) continue;

      final start = _project(beam.fromLat, beam.fromLng, center, radius);
      final end = _project(beam.toLat, beam.toLng, center, radius);
      if (start == null || end == null) continue;
      final control = Offset(
        (start.dx + end.dx) / 2,
        math.min(start.dy, end.dy) - radius * (0.24 + progress * 0.10),
      );

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = beam.color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );

      final head = _quadraticPoint(start, control, end, progress);
      final tail = _quadraticPoint(
        start,
        control,
        end,
        (progress - 0.18).clamp(0.0, 1.0).toDouble(),
      );
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..shader = uiGradientLinear(tail, head, [
            beam.color.withValues(alpha: 0.0),
            beam.color.withValues(alpha: 0.75),
            Colors.white,
          ])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      if (beam.toLabel != null && progress > 0.82) {
        _drawLabel(canvas, beam.toLabel!, end);
      }
    }
  }

  void _drawLabel(Canvas canvas, String label, Offset anchor) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 96);
    painter.paint(canvas, anchor.translate(-painter.width / 2, 10));
  }

  void _drawBottomGlow(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.38),
      Paint()
        ..shader = uiGradientLinear(
          Offset(0, size.height * 0.62),
          Offset(0, size.height),
          const [Color(0x00000000), Color(0x88FFF6D4)],
        ),
    );
  }

  Offset? _project(double lat, double lng, Offset center, double radius) {
    final relativeLng =
        _normalizeLongitude(lng - rotationLongitudeDegrees) * math.pi / 180;
    final latRad = lat * math.pi / 180;
    final visible = math.cos(latRad) * math.cos(relativeLng);
    if (visible < -0.16) return null;

    final x = center.dx + radius * math.cos(latRad) * math.sin(relativeLng);
    final y = center.dy - radius * math.sin(latRad);
    return Offset(x, y);
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
        oldDelegate.earthTexture != earthTexture ||
        oldDelegate.beams != beams ||
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
