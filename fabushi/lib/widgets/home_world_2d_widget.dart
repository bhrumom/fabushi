import 'dart:math' as math;
import 'dart:ui' show Shader;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/country_coordinates_service.dart';
import '../services/ip_location_service.dart';

class HomeWorld2DWidget extends StatefulWidget {
  const HomeWorld2DWidget({super.key});

  @override
  State<HomeWorld2DWidget> createState() => HomeWorld2DWidgetState();
}

class HomeWorld2DWidgetState extends State<HomeWorld2DWidget>
    with SingleTickerProviderStateMixin {
  final CountryCoordinatesService _coordService = CountryCoordinatesService();
  final IPLocationService _ipLocationService = IPLocationService();
  final List<_HomeWorldBeam> _beams = <_HomeWorldBeam>[];

  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;
  double _timeSeconds = 0;
  bool _isRenderingPaused = false;
  bool _isLocationInitialized = false;

  double? _userLatitude;
  double? _userLongitude;
  String? _userCountryCode;
  String? _currentToLabel;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _initializeServices();
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

    _lastFrame = elapsed;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _beams.removeWhere((beam) {
      final age = seconds - beam.startedAt;
      return age > beam.duration.inMilliseconds / 1000 + 1.2;
    });

    if (mounted) {
      setState(() => _timeSeconds = seconds);
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
  }

  void clearBeams() {
    if (!mounted) return;
    setState(() {
      _beams.clear();
      _currentToLabel = null;
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
          CustomPaint(
            painter: _HomeWorld2DPainter(
              timeSeconds: _timeSeconds,
              beams: List<_HomeWorldBeam>.unmodifiable(_beams),
              currentToLabel: _currentToLabel,
            ),
          ),
        ],
      ),
    );
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
  final List<_HomeWorldBeam> beams;
  final String? currentToLabel;

  const _HomeWorld2DPainter({
    required this.timeSeconds,
    required this.beams,
    required this.currentToLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final globeCenter = Offset(size.width / 2, size.height * 0.34);
    final globeRadius = (math.min(size.width, size.height) * 0.34).clamp(
      122.0,
      260.0,
    );

    _drawAtmosphere(canvas, size, globeCenter, globeRadius);
    _drawGlobeGlass(canvas, globeCenter, globeRadius);
    _drawLotusNodes(canvas, globeCenter, globeRadius);
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

  void _drawGlobeGlass(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.08,
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = uiGradientRadial(
          center.translate(-radius * 0.28, -radius * 0.22),
          radius * 1.18,
          const [
            Color(0x99FFFFFF),
            Color(0x553FE7E0),
            Color(0x22146FB1),
            Color(0x00000000),
          ],
          const [0.0, 0.35, 0.78, 1.0],
        ),
    );

    final ringPaint = Paint()
      ..color = const Color(0xCCFFF2A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(center, radius, ringPaint);

    final gridPaint = Paint()
      ..color = const Color(0x55FFFFFF)
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

  void _drawLotusNodes(Canvas canvas, Offset center, double radius) {
    const nodes = <(double, double)>[
      (34.0, 108.0),
      (23.0, 77.0),
      (1.0, 103.0),
      (-25.0, 133.0),
      (-33.0, -58.0),
      (-15.0, -47.0),
      (-32.0, 151.0),
    ];

    for (var i = 0; i < nodes.length; i++) {
      final position = _project(nodes[i].$1, nodes[i].$2, center, radius);
      final pulse = 0.5 + math.sin(timeSeconds * 1.5 + i) * 0.5;
      _drawLotusMark(canvas, position, 8 + pulse * 2.4);
    }
  }

  void _drawLotusMark(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 2.6,
      Paint()
        ..color = const Color(0x55FFD76B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    for (final angle in const [-0.75, -0.38, 0.0, 0.38, 0.75]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final petal = Path()
        ..moveTo(0, radius)
        ..quadraticBezierTo(-radius * 0.82, 0, 0, -radius * 1.45)
        ..quadraticBezierTo(radius * 0.82, 0, 0, radius)
        ..close();
      canvas.drawPath(
        petal,
        Paint()
          ..shader = uiGradientLinear(
            Offset(0, -radius * 1.5),
            Offset(0, radius),
            const [Color(0xFFFFFFFF), Color(0xFFFFD43B)],
          ),
      );
      canvas.restore();
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
      canvas.drawCircle(
        head,
        4.6,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(head, 2.0, Paint()..color = const Color(0xFFFFF4B8));

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

  Offset _project(double lat, double lng, Offset center, double radius) {
    final normalizedLng = ((lng + 540) % 360) - 180;
    final x = center.dx + (normalizedLng / 180.0) * radius * 0.82;
    final y = center.dy - (lat / 90.0) * radius * 0.56;
    return Offset(x, y);
  }

  Offset _quadraticPoint(Offset a, Offset b, Offset c, double t) {
    final oneMinus = 1 - t;
    return Offset(
      oneMinus * oneMinus * a.dx + 2 * oneMinus * t * b.dx + t * t * c.dx,
      oneMinus * oneMinus * a.dy + 2 * oneMinus * t * b.dy + t * t * c.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _HomeWorld2DPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.beams != beams ||
        oldDelegate.currentToLabel != currentToLabel;
  }
}

Shader uiGradientRadial(
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

Shader uiGradientLinear(Offset start, Offset end, List<Color> colors) {
  return LinearGradient(
    colors: colors,
  ).createShader(Rect.fromPoints(start, end));
}
