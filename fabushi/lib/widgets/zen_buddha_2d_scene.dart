import 'dart:math' as math;
import 'dart:ui' show Shader;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'zen_room_2d_elements.dart';

class ZenBuddha2DScene extends StatefulWidget {
  final bool autoRotate;
  final bool isBurning;
  final double incenseProgress;
  final bool showBook;
  final String? bookTitle;
  final VoidCallback? onBookTap;
  final bool isVisible;

  const ZenBuddha2DScene({
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
  State<ZenBuddha2DScene> createState() => ZenBuddha2DSceneState();
}

class ZenBuddha2DSceneState extends State<ZenBuddha2DScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;
  double _timeSeconds = 0;
  double _incenseProgress = 0;
  bool _autoRotate = false;

  @override
  void initState() {
    super.initState();
    _incenseProgress = widget.incenseProgress;
    _autoRotate = widget.autoRotate;
    _ticker = createTicker(_onTick);
    if (widget.isVisible) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!widget.isVisible) return;
    if (elapsed - _lastFrame < const Duration(milliseconds: 33)) return;

    _lastFrame = elapsed;
    if (mounted) {
      setState(() {
        _timeSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ZenBuddha2DScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _incenseProgress = widget.incenseProgress;
    _autoRotate = widget.autoRotate;
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        _lastFrame = Duration.zero;
        if (!_ticker.isTicking) _ticker.start();
      } else {
        _ticker.stop();
      }
    }
  }

  void updateIncenseProgress(double progress) {
    _incenseProgress = progress;
  }

  void setAutoRotate(bool enabled) {
    if (!mounted) return;
    setState(() => _autoRotate = enabled);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final buddhaHeight = (size.height * 0.54).clamp(310.0, 570.0);
          final buddhaWidth = buddhaHeight * 0.75;
          final breathing = math.sin(_timeSeconds * math.pi * 0.42) * 0.012;
          final floatOffset = math.sin(_timeSeconds * math.pi * 0.34) * 4.0;
          final buddhaTop = (size.height * 0.075 + floatOffset)
              .clamp(18.0, size.height * 0.25)
              .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/zen_room_backdrop_2d.webp',
                fit: BoxFit.cover,
              ),
              CustomPaint(
                painter: _ZenRoomHaloPainter(
                  timeSeconds: _timeSeconds,
                  autoRotate: _autoRotate,
                ),
              ),
              Positioned(
                left: (size.width - buddhaWidth) / 2,
                top: buddhaTop,
                width: buddhaWidth,
                height: buddhaHeight,
                child: Transform.scale(
                  scale: 1.0 + breathing,
                  child: Image.asset(
                    'assets/images/zen_buddha_2d.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              CustomPaint(
                painter: _ZenRoomForegroundPainter(
                  timeSeconds: _timeSeconds,
                  isBurning: widget.isBurning,
                  incenseProgress: _incenseProgress,
                ),
              ),
              if (widget.showBook && widget.bookTitle != null)
                Positioned(
                  left: (size.width - 118) / 2,
                  top: (size.height * 0.66)
                      .clamp(0.0, size.height - 170)
                      .toDouble(),
                  child: SutraBookButton(
                    title: widget.bookTitle!,
                    width: 118,
                    height: 118 * SutraBookButton.aspectRatioHeight,
                    onTap: widget.onBookTap,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ZenRoomHaloPainter extends CustomPainter {
  final double timeSeconds;
  final bool autoRotate;

  const _ZenRoomHaloPainter({
    required this.timeSeconds,
    required this.autoRotate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final center = Offset(size.width / 2, size.height * 0.285);
    final baseRadius = (math.min(size.width, size.height) * 0.30).clamp(
      108.0,
      230.0,
    );
    final pulse = 0.5 + math.sin(timeSeconds * 1.05) * 0.5;

    canvas.drawCircle(
      center,
      baseRadius * (1.06 + pulse * 0.03),
      Paint()
        ..shader = uiRadial(center, baseRadius * 1.25, const [
          Color(0x77FFF8D4),
          Color(0x44FFD76B),
          Color(0x00FFD76B),
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final ringPaint = Paint()
      ..color = const Color(0xAAFFF2A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    for (var i = 0; i < 4; i++) {
      final radius = baseRadius * (0.68 + i * 0.18 + pulse * 0.01);
      canvas.drawCircle(
        center,
        radius,
        ringPaint..strokeWidth = 0.8 + i * 0.25,
      );
    }

    if (autoRotate) {
      _drawOrbitLotuses(canvas, center, baseRadius, timeSeconds * 0.55);
    } else {
      _drawOrbitLotuses(canvas, center, baseRadius, timeSeconds * 0.12);
    }
  }

  void _drawOrbitLotuses(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
  ) {
    for (var i = 0; i < 8; i++) {
      final angle = rotation + i * math.pi / 4;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final scale = 0.72 + (i % 2) * 0.18;
      canvas.drawCircle(
        position,
        16 * scale,
        Paint()
          ..color = const Color(0x33FFD76B)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      for (final petalAngle in const [-0.55, -0.25, 0.0, 0.25, 0.55]) {
        canvas.save();
        canvas.translate(position.dx, position.dy);
        canvas.rotate(angle + petalAngle);
        final petal = Path()
          ..moveTo(0, 7 * scale)
          ..quadraticBezierTo(-6 * scale, 0, 0, -13 * scale)
          ..quadraticBezierTo(6 * scale, 0, 0, 7 * scale)
          ..close();
        canvas.drawPath(
          petal,
          Paint()
            ..shader = uiLinear(
              Offset(0, -13 * scale),
              Offset(0, 7 * scale),
              const [Color(0xFFFFFFFF), Color(0xFFFFCC45)],
            ),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ZenRoomHaloPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.autoRotate != autoRotate;
  }
}

class _ZenRoomForegroundPainter extends CustomPainter {
  final double timeSeconds;
  final bool isBurning;
  final double incenseProgress;

  const _ZenRoomForegroundPainter({
    required this.timeSeconds,
    required this.isBurning,
    required this.incenseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    _drawSunMotes(canvas, size);
    if (isBurning) {
      _drawPracticeAura(canvas, size);
      _drawIncenseWisps(canvas, size);
    }
  }

  void _drawSunMotes(Canvas canvas, Size size) {
    for (var i = 0; i < 20; i++) {
      final phase = timeSeconds * 0.05 + i * 0.41;
      final x = (math.sin(phase * 1.7) * 0.5 + 0.5) * size.width;
      final y = (math.cos(phase * 1.3) * 0.5 + 0.5) * size.height * 0.72;
      final opacity = 0.08 + (math.sin(phase * 3.0) * 0.5 + 0.5) * 0.16;
      canvas.drawCircle(
        Offset(x, y),
        1.2 + (i % 3) * 0.9,
        Paint()
          ..color = Color.fromRGBO(255, 241, 182, opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  void _drawPracticeAura(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.28, size.height * 0.68);
    final pulse = 0.5 + math.sin(timeSeconds * 1.3) * 0.5;
    canvas.drawCircle(
      center.translate(0, 24),
      54 + pulse * 8,
      Paint()
        ..shader = uiRadial(center.translate(0, 24), 68, const [
          Color(0x44FFF2A8),
          Color(0x00FFF2A8),
        ]),
    );

    final bodyPaint = Paint()
      ..color = const Color(0xBB3A2617)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2);
    canvas.drawCircle(center.translate(0, -27), 12, bodyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 36, height: 46),
        const Radius.circular(18),
      ),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(-18, 28), width: 52, height: 18),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(18, 28), width: 52, height: 18),
      bodyPaint,
    );
  }

  void _drawIncenseWisps(Canvas canvas, Size size) {
    final remaining = (1.0 - incenseProgress).clamp(0.18, 1.0).toDouble();
    final base = Offset(size.width / 2, size.height * 0.665);
    final tip = base.translate(0, -82 * remaining);

    for (var i = 0; i < 9; i++) {
      final t = (timeSeconds * 0.10 + i / 9.0) % 1.0;
      final drift = math.sin(timeSeconds * 0.6 + i) * (8 + t * 24);
      final end = tip.translate(drift, -150 * t);
      final c1 = tip.translate(math.cos(i + timeSeconds) * 12, -48 * t);
      final c2 = tip.translate(drift * 0.45, -110 * t);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      final opacity = (math.pow(1 - t, 1.4) * 0.36).clamp(0.0, 0.36).toDouble();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 + t * 1.4
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + t * 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ZenRoomForegroundPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.isBurning != isBurning ||
        oldDelegate.incenseProgress != incenseProgress;
  }
}

Shader uiRadial(Offset center, double radius, List<Color> colors) {
  return RadialGradient(
    colors: colors,
  ).createShader(Rect.fromCircle(center: center, radius: radius));
}

Shader uiLinear(Offset start, Offset end, List<Color> colors) {
  return LinearGradient(
    colors: colors,
  ).createShader(Rect.fromPoints(start, end));
}
