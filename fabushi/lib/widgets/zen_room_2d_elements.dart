import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class IncensePainter extends CustomPainter {
  final double incenseProgress;
  final bool isBurning;

  IncensePainter({required this.incenseProgress, required this.isBurning});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    _drawFixedIncense(canvas, size);
  }

  void _drawFixedIncense(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.70);
    final remaining = (1.0 - incenseProgress).clamp(0.16, 1.0).toDouble();
    final stickHeight = 88.0 * remaining;
    final haloRect = Rect.fromCenter(
      center: base.translate(0, -24),
      width: 170,
      height: 178,
    );
    canvas.drawOval(
      haloRect,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    _drawIncenseBurner(canvas, base, stickHeight);

    for (final offset in const [-14.0, 0.0, 14.0]) {
      final stickBase = base.translate(offset, -8);
      final stickTip = stickBase.translate(0, -stickHeight);
      canvas.drawLine(
        stickBase,
        stickTip,
        Paint()
          ..color = const Color(0xAA1A0904)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawLine(
        stickBase,
        stickTip,
        Paint()
          ..shader = ui.Gradient.linear(
            stickBase,
            stickTip,
            const [Color(0xFF5A2E16), Color(0xFFE7B45F), Color(0xFF2B1509)],
            const [0.0, 0.5, 1.0],
          )
          ..strokeWidth = 4.0
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
      final opacity = ((1 - t) * 0.17 + 0.025).clamp(0.0, 0.20).toDouble();
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.fromRGBO(235, 229, 214, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + t * 7),
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
            ..color = Color.fromRGBO(242, 236, 220, opacity * 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0 + t
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  void _drawIncenseBurner(Canvas canvas, Offset center, double stickHeight) {
    final width = (stickHeight * 1.24).clamp(58.0, 112.0).toDouble();
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
  bool shouldRepaint(covariant IncensePainter oldDelegate) {
    return true;
  }
}

class IncenseSmokeOverlay extends StatelessWidget {
  final double incenseProgress;
  final bool isBurning;
  final double smokeRise;

  const IncenseSmokeOverlay({
    super.key,
    required this.incenseProgress,
    required this.isBurning,
    this.smokeRise = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (!isBurning) {
      return const SizedBox.expand();
    }

    return CustomPaint(
      painter: IncenseSmokeOverlayPainter(
        incenseProgress: incenseProgress,
        smokeRise: smokeRise,
        isBurning: isBurning,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class IncenseSmokeOverlayPainter extends CustomPainter {
  final double incenseProgress;
  final double smokeRise;
  final bool isBurning;

  const IncenseSmokeOverlayPainter({
    required this.incenseProgress,
    required this.smokeRise,
    required this.isBurning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final time = DateTime.now().millisecondsSinceEpoch * 0.001;
    final remaining = (1.0 - incenseProgress).clamp(0.18, 1.0).toDouble();
    final incenseAreaHeight = (size.height - smokeRise).clamp(1.0, size.height);
    final scale = math.min(size.width / 150.0, incenseAreaHeight / 184.0);
    final bowlTop = smokeRise + incenseAreaHeight - 62.0 * scale;
    final stickHeight = 90.0 * scale * remaining;
    final tipY = bowlTop - 3.0 * scale - stickHeight;
    final centerX = size.width / 2;

    if (isBurning) {
      for (final seed in const [-22.0, 0.0, 22.0]) {
        final scaledSeed = seed * scale;
        final tip = Offset(centerX + scaledSeed, tipY);
        _drawEmber(canvas, tip, scale);
      }
    }

    for (final seed in const [-22.0, 0.0, 22.0]) {
      final scaledSeed = seed * scale;
      final tip = Offset(centerX + scaledSeed, tipY);
      _drawSmokeColumn(canvas, tip, time, scaledSeed);
    }
  }

  void _drawEmber(Canvas canvas, Offset tip, double scale) {
    canvas.drawCircle(
      tip,
      8.0 * scale,
      Paint()
        ..shader = ui.Gradient.radial(
          tip,
          10.0 * scale,
          const [Color(0xBBFFD54F), Color(0x66FF5722), Color(0x00FF0000)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawCircle(
      tip,
      2.5 * scale,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  void _drawSmokeColumn(Canvas canvas, Offset tip, double time, double seed) {
    for (var i = 0; i < 6; i++) {
      final t = (time * 0.08 + i / 6 + seed * 0.02) % 1.0;

      final drift =
          math.sin(t * math.pi * 2.0 + time * 0.4 + seed) * (2 + t * 8);
      final end = Offset(tip.dx + drift, tip.dy - smokeRise * t);

      final controlOne = Offset(
        tip.dx + math.sin(time * 0.3 + i) * (1 + t * 2),
        tip.dy - smokeRise * (t * 0.3),
      );
      final controlTwo = Offset(
        tip.dx + drift * 0.5 + math.cos(time * 0.4 + seed) * (1 + t * 4),
        tip.dy - smokeRise * (t * 0.7),
      );

      final opacity = (math.pow(1 - t, 1.5) * 0.55).clamp(0.0, 0.55).toDouble();
      final stroke = (1.5 + t * 1.0).clamp(1.2, 2.5).toDouble();

      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..cubicTo(
          controlOne.dx,
          controlOne.dy,
          controlTwo.dx,
          controlTwo.dy,
          end.dx,
          end.dy,
        );

      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromRGBO(230, 235, 240, opacity)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 + t * 4.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant IncenseSmokeOverlayPainter oldDelegate) {
    return true; // Must repaint every frame for smoke animation
  }
}

class IncenseOffering extends StatelessWidget {
  final double incenseProgress;
  final bool isBurning;

  const IncenseOffering({
    super.key,
    required this.incenseProgress,
    required this.isBurning,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: IncenseOfferingPainter(
        incenseProgress: incenseProgress,
        isBurning: isBurning,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class IncenseOfferingPainter extends CustomPainter {
  final double incenseProgress;
  final bool isBurning;

  const IncenseOfferingPainter({
    required this.incenseProgress,
    required this.isBurning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final scale = math.min(size.width / 150.0, size.height / 184.0);
    final centerX = size.width / 2;

    final bowlTop = size.height - 62 * scale;
    final bowlBottom = size.height - 24 * scale;
    final rimCenter = Offset(centerX, bowlTop);

    final remaining = (1.0 - incenseProgress).clamp(0.18, 1.0).toDouble();
    final stickHeight = 90.0 * scale * remaining;

    _drawBowlShadow(canvas, centerX, bowlBottom, scale);
    _drawFeet(canvas, centerX, bowlBottom, scale);
    _drawHandles(canvas, rimCenter, scale);
    _drawBowl(canvas, rimCenter, bowlBottom, scale);

    for (final dx in const [-22.0, 0.0, 22.0]) {
      final base = Offset(centerX + dx * scale, bowlTop - 3 * scale);
      final tip = base.translate(0, -stickHeight);
      _drawStick(canvas, base, tip, scale);
    }
  }

  void _drawBowlShadow(
    Canvas canvas,
    double centerX,
    double bottom,
    double scale,
  ) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, bottom + 12 * scale),
        width: 112 * scale,
        height: 14 * scale,
      ),
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale),
    );
  }

  void _drawHandles(Canvas canvas, Offset rimCenter, double scale) {
    final leftEar = Path()
      ..moveTo(rimCenter.dx - 48 * scale, rimCenter.dy + 8 * scale)
      ..cubicTo(
        rimCenter.dx - 62 * scale,
        rimCenter.dy - 12 * scale,
        rimCenter.dx - 54 * scale,
        rimCenter.dy - 22 * scale,
        rimCenter.dx - 42 * scale,
        rimCenter.dy - 6 * scale,
      );
    final rightEar = Path()
      ..moveTo(rimCenter.dx + 48 * scale, rimCenter.dy + 8 * scale)
      ..cubicTo(
        rimCenter.dx + 62 * scale,
        rimCenter.dy - 12 * scale,
        rimCenter.dx + 54 * scale,
        rimCenter.dy - 22 * scale,
        rimCenter.dx + 42 * scale,
        rimCenter.dy - 6 * scale,
      );

    final earPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5 * scale
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(rimCenter.dx - 60 * scale, rimCenter.dy - 15 * scale),
        Offset(rimCenter.dx + 60 * scale, rimCenter.dy + 10 * scale),
        const [Color(0xFFD4AF37), Color(0xFF8B5A2B), Color(0xFF3E2010)],
        const [0.0, 0.5, 1.0],
      );

    canvas.drawPath(leftEar, earPaint);
    canvas.drawPath(rightEar, earPaint);

    final earInnerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFD76B);

    canvas.drawPath(leftEar, earInnerPaint);
    canvas.drawPath(rightEar, earInnerPaint);
  }

  void _drawFeet(
    Canvas canvas,
    double centerX,
    double bowlBottom,
    double scale,
  ) {
    final footStroke = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;

    final leftFoot = Path()
      ..moveTo(centerX - 36 * scale, bowlBottom - 4 * scale)
      ..quadraticBezierTo(
        centerX - 38 * scale,
        bowlBottom + 12 * scale,
        centerX - 32 * scale,
        bowlBottom + 16 * scale,
      )
      ..quadraticBezierTo(
        centerX - 24 * scale,
        bowlBottom + 12 * scale,
        centerX - 24 * scale,
        bowlBottom - 4 * scale,
      )
      ..close();

    final leftFootPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - 38 * scale, bowlBottom),
        Offset(centerX - 24 * scale, bowlBottom + 16 * scale),
        const [Color(0xFF3E2010), Color(0xFF8B5A2B), Color(0xFF3E2010)],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawPath(leftFoot, leftFootPaint);
    canvas.drawPath(leftFoot, footStroke);

    final rightFoot = Path()
      ..moveTo(centerX + 24 * scale, bowlBottom - 4 * scale)
      ..quadraticBezierTo(
        centerX + 24 * scale,
        bowlBottom + 12 * scale,
        centerX + 32 * scale,
        bowlBottom + 16 * scale,
      )
      ..quadraticBezierTo(
        centerX + 38 * scale,
        bowlBottom + 12 * scale,
        centerX + 36 * scale,
        bowlBottom - 4 * scale,
      )
      ..close();

    final rightFootPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX + 24 * scale, bowlBottom),
        Offset(centerX + 38 * scale, bowlBottom + 16 * scale),
        const [Color(0xFF3E2010), Color(0xFF8B5A2B), Color(0xFF3E2010)],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawPath(rightFoot, rightFootPaint);
    canvas.drawPath(rightFoot, footStroke);

    final centerFoot = Path()
      ..moveTo(centerX - 8 * scale, bowlBottom - 2 * scale)
      ..quadraticBezierTo(
        centerX - 10 * scale,
        bowlBottom + 15 * scale,
        centerX,
        bowlBottom + 18 * scale,
      )
      ..quadraticBezierTo(
        centerX + 10 * scale,
        bowlBottom + 15 * scale,
        centerX + 8 * scale,
        bowlBottom - 2 * scale,
      )
      ..close();

    final centerFootPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - 10 * scale, bowlBottom),
        Offset(centerX + 10 * scale, bowlBottom + 18 * scale),
        const [Color(0xFF5C2F15), Color(0xFFD4AF37), Color(0xFF3E2010)],
        const [0.0, 0.5, 1.0],
      );

    canvas.drawPath(centerFoot, centerFootPaint);
    canvas.drawPath(centerFoot, footStroke);
  }

  void _drawBowl(
    Canvas canvas,
    Offset rimCenter,
    double bowlBottom,
    double scale,
  ) {
    final body = Path()
      ..moveTo(rimCenter.dx - 45 * scale, rimCenter.dy)
      ..cubicTo(
        rimCenter.dx - 54 * scale,
        rimCenter.dy + 12 * scale,
        rimCenter.dx - 48 * scale,
        bowlBottom - 6 * scale,
        rimCenter.dx - 22 * scale,
        bowlBottom,
      )
      ..lineTo(rimCenter.dx + 22 * scale, bowlBottom)
      ..cubicTo(
        rimCenter.dx + 48 * scale,
        bowlBottom - 6 * scale,
        rimCenter.dx + 54 * scale,
        rimCenter.dy + 12 * scale,
        rimCenter.dx + 45 * scale,
        rimCenter.dy,
      )
      ..close();

    final bellyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(rimCenter.dx - 12 * scale, rimCenter.dy + 18 * scale),
        60 * scale,
        const [
          Color(0xFFFFF0B8),
          Color(0xFFD4AF37),
          Color(0xFF8B5A2B),
          Color(0xFF3E2010),
          Color(0xFF1B0C06),
        ],
        const [0.0, 0.22, 0.55, 0.88, 1.0],
      );

    canvas.drawPath(body, bellyPaint);

    final bellyStroke = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale;
    canvas.drawPath(body, bellyStroke);

    final decRect = Rect.fromCenter(
      center: rimCenter.translate(0, 3 * scale),
      width: 86 * scale,
      height: 4 * scale,
    );
    canvas.drawRect(
      decRect,
      Paint()
        ..shader = ui.Gradient.linear(
          decRect.topLeft,
          decRect.bottomRight,
          const [Color(0xFF8B5A2B), Color(0xFFFFD76B), Color(0xFF3E2010)],
          const [0.0, 0.5, 1.0],
        ),
    );

    final rimRect = Rect.fromCenter(
      center: rimCenter,
      width: 98 * scale,
      height: 16 * scale,
    );

    canvas.drawOval(
      rimRect,
      Paint()
        ..shader = ui.Gradient.linear(
          rimRect.topLeft,
          rimRect.bottomRight,
          const [Color(0xFFFFD76B), Color(0xFF8B5A2B), Color(0xFFFFE08A)],
          const [0.0, 0.5, 1.0],
        ),
    );

    canvas.drawOval(
      rimRect,
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );

    final innerRimRect = Rect.fromCenter(
      center: rimCenter,
      width: rimRect.width * 0.90,
      height: rimRect.height * 0.85,
    );
    canvas.drawOval(innerRimRect, Paint()..color = const Color(0xFF200F07));

    final ashRect = Rect.fromCenter(
      center: rimCenter.translate(0, 0.5 * scale),
      width: innerRimRect.width * 0.92,
      height: innerRimRect.height * 0.85,
    );
    canvas.drawOval(
      ashRect,
      Paint()
        ..shader = ui.Gradient.radial(
          rimCenter,
          ashRect.width / 2,
          const [Color(0xFF8A8279), Color(0xFF4E463E), Color(0xFF251A12)],
          const [0.0, 0.65, 1.0],
        ),
    );
  }

  void _drawStick(Canvas canvas, Offset base, Offset tip, double scale) {
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = const Color(0xAA1F0E08)
        ..strokeWidth = 5.2 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..shader = ui.Gradient.linear(
          base,
          tip,
          const [Color(0xFF4A1F0D), Color(0xFFC67735), Color(0xFFECC36C)],
          const [0.0, 0.5, 1.0],
        )
        ..strokeWidth = 3.0 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant IncenseOfferingPainter oldDelegate) {
    return oldDelegate.incenseProgress != incenseProgress ||
        oldDelegate.isBurning != isBurning;
  }
}

class SutraBookButton extends StatelessWidget {
  static const double baseWidth = 100;
  static const double baseHeight = 142;
  static const double aspectRatioHeight = baseHeight / baseWidth;

  final String title;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const SutraBookButton({
    super.key,
    required this.title,
    this.onTap,
    this.width = baseWidth,
    this.height = baseHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Formats text vertically (Traditional Chinese binding style)
    // If name is long, split into multiple columns (Right-to-Left)
    final columns = <String>[];
    if (title.length > 6) {
      final half = (title.length / 2).ceil();
      columns.add(title.substring(half).split('').join('\n'));
      columns.add(title.substring(0, half).split('').join('\n'));
    } else {
      columns.add(title.split('').join('\n'));
    }

    final labelWidth = title.length > 6 ? 42.0 : 25.0;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: title,
        child: SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Container(
              width: baseWidth,
              height: baseHeight,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 10,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ThreadBoundBookPainter()),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    bottom: 14,
                    width: labelWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFBF7),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: const Color(0xFF2C1E1A).withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 2,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 2,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: columns
                              .map(
                                (col) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2.0,
                                  ),
                                  child: Text(
                                    col,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF2C1E1A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                      fontFamily: 'serif',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadBoundBookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, ui.Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    final coverPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [Color(0xFF1C2C54), Color(0xFF0F1A35), Color(0xFF080E1E)],
        const [0.0, 0.70, 1.0],
      );
    canvas.drawRRect(rrect, coverPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [Color(0xFFFFD76B), Color(0xFF8B5A2B), Color(0xFFFFD76B)],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(rrect.deflate(2.0), borderPaint);

    final threadPaint = Paint()
      ..color = const Color(0xFFECC36C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double spineX = size.width - 8.0;
    canvas.drawLine(
      Offset(spineX, 0),
      Offset(spineX, size.height),
      threadPaint,
    );

    final double stitchOffset = 16.0;
    final int stitches = 6;
    final double step = (size.height - stitchOffset * 2) / (stitches - 1);

    for (int i = 0; i < stitches; i++) {
      final double y = stitchOffset + i * step;
      canvas.drawLine(Offset(spineX, y), Offset(size.width, y), threadPaint);
      canvas.drawCircle(
        Offset(spineX, y),
        1.2,
        Paint()..color = const Color(0xFF3E2010),
      );
      canvas.drawCircle(
        Offset(spineX, y),
        0.7,
        Paint()..color = const Color(0xFFECC36C),
      );
    }

    canvas.drawLine(
      Offset(spineX, stitchOffset),
      Offset(size.width - 2, 0),
      threadPaint,
    );
    canvas.drawLine(
      Offset(spineX, size.height - stitchOffset),
      Offset(size.width - 2, size.height),
      threadPaint,
    );

    final cornerPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(const Offset(0, 0), 12, const [
        Color(0xFFFFD76B),
        Color(0xFF8B5A2B),
      ]);

    final topLeftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(10, 0)
      ..lineTo(0, 10)
      ..close();
    canvas.drawPath(topLeftPath, cornerPaint);

    final bottomLeftPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(10, size.height)
      ..lineTo(0, size.height - 10)
      ..close();
    canvas.drawPath(bottomLeftPath, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ButterLampOffering extends StatefulWidget {
  final bool isBurning;

  const ButterLampOffering({super.key, required this.isBurning});

  @override
  State<ButterLampOffering> createState() => _ButterLampOfferingState();
}

class _ButterLampOfferingState extends State<ButterLampOffering>
    with SingleTickerProviderStateMixin {
  late AnimationController _flameController;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flameController,
      builder: (context, _) {
        return CustomPaint(
          painter: _ButterLampPainter(
            flameIntensity: _flameController.value,
            isBurning: widget.isBurning,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ButterLampPainter extends CustomPainter {
  final double flameIntensity;
  final bool isBurning;

  const _ButterLampPainter({
    required this.flameIntensity,
    required this.isBurning,
  });

  @override
  void paint(Canvas canvas, ui.Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final scale = math.min(size.width / 100.0, size.height / 140.0);
    final centerX = size.width / 2;
    final bottomY = size.height - 10 * scale;

    final pedestalPath = Path()
      ..moveTo(centerX - 24 * scale, bottomY)
      ..lineTo(centerX + 24 * scale, bottomY)
      ..quadraticBezierTo(
        centerX + 18 * scale,
        bottomY - 15 * scale,
        centerX + 12 * scale,
        bottomY - 30 * scale,
      )
      ..lineTo(centerX - 12 * scale, bottomY - 30 * scale)
      ..quadraticBezierTo(
        centerX - 18 * scale,
        bottomY - 15 * scale,
        centerX - 24 * scale,
        bottomY,
      )
      ..close();

    final goldGradient = ui.Gradient.linear(
      Offset(centerX - 24 * scale, bottomY - 15 * scale),
      Offset(centerX + 24 * scale, bottomY - 15 * scale),
      const [
        Color(0xFF8B5A2B),
        Color(0xFFFFD76B),
        Color(0xFFFFF0B8),
        Color(0xFFD4AF37),
        Color(0xFF8B5A2B),
      ],
      const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    canvas.drawPath(pedestalPath, Paint()..shader = goldGradient);

    final bowlY = bottomY - 30 * scale;
    final bowlPath = Path()
      ..moveTo(centerX - 12 * scale, bowlY)
      ..quadraticBezierTo(
        centerX - 35 * scale,
        bowlY - 15 * scale,
        centerX - 30 * scale,
        bowlY - 35 * scale,
      )
      ..lineTo(centerX + 30 * scale, bowlY - 35 * scale)
      ..quadraticBezierTo(
        centerX + 35 * scale,
        bowlY - 15 * scale,
        centerX + 12 * scale,
        bowlY,
      )
      ..close();

    canvas.drawPath(bowlPath, Paint()..shader = goldGradient);

    final rimCenter = Offset(centerX, bowlY - 35 * scale);
    canvas.drawOval(
      Rect.fromCenter(center: rimCenter, width: 62 * scale, height: 18 * scale),
      Paint()..shader = goldGradient,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: rimCenter.translate(0, 1 * scale),
        width: 56 * scale,
        height: 14 * scale,
      ),
      Paint()..color = const Color(0xFFFDE89F),
    );

    if (isBurning) {
      final wickTop = rimCenter.translate(0, -6 * scale);
      canvas.drawLine(
        rimCenter,
        wickTop,
        Paint()
          ..color = const Color(0xFF1A1A1A)
          ..strokeWidth = 2 * scale,
      );

      final time = DateTime.now().millisecondsSinceEpoch * 0.001;
      final noiseX =
          math.sin(time * 5.0) * 0.5 +
          math.sin(time * 3.1) * 0.3 +
          math.sin(time * 7.3) * 0.2;
      final noiseY =
          math.sin(time * 4.0) * 0.5 +
          math.sin(time * 2.7) * 0.3 +
          math.sin(time * 8.1) * 0.2;

      final flutterX = noiseX * 2.5 * scale;
      final stretchY = noiseY * 3.0 * scale;

      final flameCenter = wickTop.translate(0, -2 * scale);
      final flameTip = flameCenter.translate(
        flutterX,
        -22 * scale - stretchY - flameIntensity * 2 * scale,
      );

      canvas.drawCircle(
        flameCenter.translate(0, -10 * scale),
        28 * scale + flameIntensity * 4 * scale,
        Paint()
          ..shader = ui.Gradient.radial(
            flameCenter.translate(0, -8 * scale),
            32 * scale,
            const [Color(0x55FF9900), Color(0x00FF9900)],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      final outerFlame = Path()
        ..moveTo(flameTip.dx, flameTip.dy)
        ..quadraticBezierTo(
          flameCenter.dx + 12 * scale,
          flameCenter.dy - 10 * scale,
          flameCenter.dx + 7 * scale,
          flameCenter.dy + 2 * scale,
        )
        ..quadraticBezierTo(
          flameCenter.dx,
          flameCenter.dy + 6 * scale,
          flameCenter.dx - 7 * scale,
          flameCenter.dy + 2 * scale,
        )
        ..quadraticBezierTo(
          flameCenter.dx - 12 * scale,
          flameCenter.dy - 10 * scale,
          flameTip.dx,
          flameTip.dy,
        )
        ..close();

      canvas.drawPath(
        outerFlame,
        Paint()
          ..shader = ui.Gradient.radial(
            flameCenter.translate(0, -4 * scale),
            18 * scale,
            const [Color(0x000000FF), Color(0xFFFF9900), Color(0xFFFF3300)],
            const [0.0, 0.6, 1.0],
          ),
      );

      final innerTip = flameCenter.translate(
        flutterX * 0.5,
        -14 * scale - stretchY * 0.5,
      );
      final innerFlame = Path()
        ..moveTo(innerTip.dx, innerTip.dy)
        ..quadraticBezierTo(
          flameCenter.dx + 6 * scale,
          flameCenter.dy - 6 * scale,
          flameCenter.dx + 4 * scale,
          flameCenter.dy,
        )
        ..quadraticBezierTo(
          flameCenter.dx,
          flameCenter.dy + 3 * scale,
          flameCenter.dx - 4 * scale,
          flameCenter.dy,
        )
        ..quadraticBezierTo(
          flameCenter.dx - 6 * scale,
          flameCenter.dy - 6 * scale,
          innerTip.dx,
          innerTip.dy,
        )
        ..close();

      canvas.drawPath(
        innerFlame,
        Paint()
          ..shader = ui.Gradient.radial(
            flameCenter,
            10 * scale,
            const [Color(0xFFFFFFFF), Color(0xFFFFEEAA), Color(0x00FFEEAA)],
            const [0.0, 0.4, 1.0],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ButterLampPainter oldDelegate) {
    return oldDelegate.flameIntensity != flameIntensity ||
        oldDelegate.isBurning != isBurning;
  }
}

class FruitFlowerOffering extends StatelessWidget {
  const FruitFlowerOffering({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FruitFlowerPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _FruitFlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, ui.Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final scale = math.min(size.width / 120.0, size.height / 120.0);
    final centerX = size.width / 2;
    final bottomY = size.height - 10 * scale;

    final bowlY = bottomY - 30 * scale;
    final goldGradient = ui.Gradient.linear(
      Offset(centerX - 40 * scale, bowlY),
      Offset(centerX + 40 * scale, bowlY),
      const [
        Color(0xFF8B5A2B),
        Color(0xFFFFD76B),
        Color(0xFFFFF0B8),
        Color(0xFFD4AF37),
        Color(0xFF8B5A2B),
      ],
      const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final pedestalPath = Path()
      ..moveTo(centerX - 20 * scale, bottomY)
      ..lineTo(centerX + 20 * scale, bottomY)
      ..lineTo(centerX + 12 * scale, bowlY)
      ..lineTo(centerX - 12 * scale, bowlY)
      ..close();
    canvas.drawPath(pedestalPath, Paint()..shader = goldGradient);

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX, bowlY - 15 * scale),
        width: 90 * scale,
        height: 60 * scale,
      ),
      0,
      math.pi,
      true,
      Paint()..shader = goldGradient,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, bowlY - 15 * scale),
        width: 90 * scale,
        height: 16 * scale,
      ),
      Paint()..shader = goldGradient,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, bowlY - 15 * scale),
        width: 84 * scale,
        height: 12 * scale,
      ),
      Paint()..color = const Color(0xFF3E2010),
    );

    final fruitCenterY = bowlY - 22 * scale;

    _drawFruit(
      canvas,
      Offset(centerX - 20 * scale, fruitCenterY + 4 * scale),
      16 * scale,
      const Color(0xFFE53935),
    );
    _drawFruit(
      canvas,
      Offset(centerX + 20 * scale, fruitCenterY + 4 * scale),
      16 * scale,
      const Color(0xFFF4511E),
    );
    _drawFruit(
      canvas,
      Offset(centerX, fruitCenterY - 8 * scale),
      18 * scale,
      const Color(0xFFFFB300),
    );

    _drawLotus(
      canvas,
      Offset(centerX - 35 * scale, fruitCenterY + 5 * scale),
      scale * 0.6,
      -0.3,
    );
    _drawLotus(
      canvas,
      Offset(centerX + 35 * scale, fruitCenterY + 5 * scale),
      scale * 0.6,
      0.3,
    );
  }

  void _drawFruit(
    Canvas canvas,
    Offset center,
    double radius,
    Color baseColor,
  ) {
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.7),
        width: radius * 1.8,
        height: radius * 0.6,
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final hsl = HSLColor.fromColor(baseColor);
    final darkColor = hsl
        .withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0))
        .toColor();
    final shadowColor = hsl
        .withLightness((hsl.lightness - 0.4).clamp(0.0, 1.0))
        .toColor();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center.translate(-radius * 0.3, -radius * 0.3),
          radius * 1.2,
          [
            const Color(0xFFFFFFFF).withValues(alpha: 0.9),
            baseColor,
            darkColor,
            shadowColor,
          ],
          const [0.0, 0.2, 0.7, 1.0],
        ),
    );

    final dimpleCenter = center.translate(0, -radius * 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: dimpleCenter,
        width: radius * 0.5,
        height: radius * 0.2,
      ),
      Paint()
        ..shader = ui.Gradient.radial(dimpleCenter, radius * 0.3, [
          const Color(0xFF2A1508),
          const Color(0x002A1508),
        ]),
    );
    canvas.drawPath(
      Path()
        ..moveTo(dimpleCenter.dx, dimpleCenter.dy)
        ..quadraticBezierTo(
          dimpleCenter.dx + radius * 0.2,
          dimpleCenter.dy - radius * 0.3,
          dimpleCenter.dx + radius * 0.4,
          dimpleCenter.dy - radius * 0.5,
        ),
      Paint()
        ..color = const Color(0xFF3E2010)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.15
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLotus(Canvas canvas, Offset center, double scale, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    canvas.drawCircle(
      Offset.zero,
      20 * scale,
      Paint()
        ..color = const Color(0x44FF4081)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final petalAngles = [-0.6, 0.6, -0.3, 0.3, 0.0];

    for (int i = 0; i < petalAngles.length; i++) {
      canvas.save();
      canvas.rotate(petalAngles[i]);

      final isFront = i >= 2;
      final color1 = isFront
          ? const Color(0xFFFCE4EC)
          : const Color(0xFFF8BBD0);
      final color2 = isFront
          ? const Color(0xFFE91E63)
          : const Color(0xFFC2185B);

      final petalPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -28 * scale),
          Offset(0, 5 * scale),
          [color1, color2],
        );

      final petalPath = Path()
        ..moveTo(0, 10 * scale)
        ..quadraticBezierTo(-18 * scale, 0, 0, -28 * scale)
        ..quadraticBezierTo(18 * scale, 0, 0, 10 * scale)
        ..close();

      canvas.drawPath(petalPath, petalPaint);
      canvas.drawPath(
        petalPath,
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * scale,
      );

      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FruitFlowerPainter oldDelegate) => false;
}
