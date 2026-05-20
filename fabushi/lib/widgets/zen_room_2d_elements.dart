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
          ..shader = ui.Gradient.linear(stickBase, stickTip, const [
            Color(0xFF5A2E16),
            Color(0xFFE7B45F),
            Color(0xFF2B1509),
          ])
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round,
      );

      if (isBurning) {
        canvas.drawCircle(
          stickTip,
          6,
          Paint()
            ..shader = ui.Gradient.radial(stickTip, 8, const [
              Color(0xFFFFF1A3),
              Color(0xFFFF6B1A),
              Color(0x00FF6B1A),
            ]),
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
      ),
      child: const SizedBox.expand(),
    );
  }
}

class IncenseSmokeOverlayPainter extends CustomPainter {
  final double incenseProgress;
  final double smokeRise;

  const IncenseSmokeOverlayPainter({
    required this.incenseProgress,
    required this.smokeRise,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;

    final time = DateTime.now().millisecondsSinceEpoch * 0.001;
    final remaining = (1.0 - incenseProgress).clamp(0.18, 1.0).toDouble();
    final incenseAreaHeight = (size.height - smokeRise).clamp(1.0, size.height);
    final scale = math.min(size.width / 150.0, incenseAreaHeight / 184.0);
    final bowlTop = smokeRise + incenseAreaHeight - 52.0 * scale;
    final stickHeight = 78.0 * scale * remaining;
    final tipY = bowlTop - 4.0 * scale - stickHeight;
    final centerX = size.width / 2;

    for (final seed in const [-11.0, 0.0, 11.0]) {
      final scaledSeed = seed * scale;
      final tip = Offset(centerX + scaledSeed, tipY);
      _drawSmokeColumn(canvas, tip, time, scaledSeed);
    }
  }

  void _drawSmokeColumn(Canvas canvas, Offset tip, double time, double seed) {
    for (var i = 0; i < 8; i++) {
      final t = (time * 0.055 + i / 8 + seed * 0.011) % 1.0;
      final drift = math.sin(t * math.pi * 2.0 + seed) * (10 + t * 28);
      final sideDrift = math.cos(time * 0.45 + i + seed) * (2 + t * 8);
      final end = Offset(
        tip.dx + drift + sideDrift,
        tip.dy - smokeRise * (0.20 + t * 0.78),
      );
      final controlOne = Offset(
        tip.dx + math.sin(time * 0.35 + i) * 18,
        tip.dy - smokeRise * (0.12 + t * 0.14),
      );
      final controlTwo = Offset(
        tip.dx + drift * 0.55 + math.cos(i + seed) * 12,
        tip.dy - smokeRise * (0.36 + t * 0.36),
      );
      final opacity = ((1 - t) * 0.23 + 0.04).clamp(0.0, 0.24).toDouble();
      final stroke = (2.8 - t * 1.15).clamp(1.1, 2.8).toDouble();

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
          ..color = Color.fromRGBO(244, 238, 222, opacity)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + t * 5.5),
      );

      if (i.isEven) {
        canvas.drawCircle(
          end,
          5.5 + t * 10.0,
          Paint()
            ..color = Color.fromRGBO(236, 231, 218, opacity * 0.72)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + t * 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant IncenseSmokeOverlayPainter oldDelegate) {
    return true;
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
    
    // Position censer elements nicely
    final bowlTop = size.height - 62 * scale;
    final bowlBottom = size.height - 24 * scale;
    final rimCenter = Offset(centerX, bowlTop);
    
    final remaining = (1.0 - incenseProgress).clamp(0.18, 1.0).toDouble();
    // Incense sticks are long, slender, and beautiful
    final stickHeight = 90.0 * scale * remaining;

    // 1. Draw Bowl Shadow
    _drawBowlShadow(canvas, centerX, bowlBottom, scale);

    // 2. Draw 3D Feet
    _drawFeet(canvas, centerX, bowlBottom, scale);

    // 3. Draw Side Handles (Ears)
    _drawHandles(canvas, rimCenter, scale);

    // 4. Draw Bowl Body and Rim
    _drawBowl(canvas, rimCenter, bowlBottom, scale);

    // 5. Draw Incense Sticks and Embers
    for (final dx in const [-11.0, 0.0, 11.0]) {
      final base = Offset(centerX + dx * scale, bowlTop - 3 * scale);
      final tip = base.translate(0, -stickHeight);
      _drawStick(canvas, base, tip, scale);
      if (isBurning) {
        _drawEmber(canvas, tip, scale);
      }
    }
  }

  void _drawBowlShadow(Canvas canvas, double centerX, double bottom, double scale) {
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
    // Elegant dual loop handles (ears) curving gracefully from sides
    final leftEar = Path()
      ..moveTo(rimCenter.dx - 48 * scale, rimCenter.dy + 8 * scale)
      ..cubicTo(
        rimCenter.dx - 62 * scale, rimCenter.dy - 12 * scale,
        rimCenter.dx - 54 * scale, rimCenter.dy - 22 * scale,
        rimCenter.dx - 42 * scale, rimCenter.dy - 6 * scale,
      );
    final rightEar = Path()
      ..moveTo(rimCenter.dx + 48 * scale, rimCenter.dy + 8 * scale)
      ..cubicTo(
        rimCenter.dx + 62 * scale, rimCenter.dy - 12 * scale,
        rimCenter.dx + 54 * scale, rimCenter.dy - 22 * scale,
        rimCenter.dx + 42 * scale, rimCenter.dy - 6 * scale,
      );

    final earPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5 * scale
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(rimCenter.dx - 60 * scale, rimCenter.dy - 15 * scale),
        Offset(rimCenter.dx + 60 * scale, rimCenter.dy + 10 * scale),
        const [Color(0xFFD4AF37), Color(0xFF8B5A2B), Color(0xFF3E2010)],
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

  void _drawFeet(Canvas canvas, double centerX, double bowlBottom, double scale) {
    // Draw three 3D tripod feet with shadow/metallic styling
    final footStroke = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;

    // Left foot
    final leftFoot = Path()
      ..moveTo(centerX - 36 * scale, bowlBottom - 4 * scale)
      ..quadraticBezierTo(centerX - 38 * scale, bowlBottom + 12 * scale, centerX - 32 * scale, bowlBottom + 16 * scale)
      ..quadraticBezierTo(centerX - 24 * scale, bowlBottom + 12 * scale, centerX - 24 * scale, bowlBottom - 4 * scale)
      ..close();
      
    final leftFootPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - 38 * scale, bowlBottom),
        Offset(centerX - 24 * scale, bowlBottom + 16 * scale),
        const [Color(0xFF3E2010), Color(0xFF8B5A2B), Color(0xFF3E2010)],
      );
    canvas.drawPath(leftFoot, leftFootPaint);
    canvas.drawPath(leftFoot, footStroke);

    // Right foot
    final rightFoot = Path()
      ..moveTo(centerX + 24 * scale, bowlBottom - 4 * scale)
      ..quadraticBezierTo(centerX + 24 * scale, bowlBottom + 12 * scale, centerX + 32 * scale, bowlBottom + 16 * scale)
      ..quadraticBezierTo(centerX + 38 * scale, bowlBottom + 12 * scale, centerX + 36 * scale, bowlBottom - 4 * scale)
      ..close();
      
    final rightFootPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX + 24 * scale, bowlBottom),
        Offset(centerX + 38 * scale, bowlBottom + 16 * scale),
        const [Color(0xFF3E2010), Color(0xFF8B5A2B), Color(0xFF3E2010)],
      );
    canvas.drawPath(rightFoot, rightFootPaint);
    canvas.drawPath(rightFoot, footStroke);

    // Center foot (rendered in front with a bright brass shine)
    final centerFoot = Path()
      ..moveTo(centerX - 8 * scale, bowlBottom - 2 * scale)
      ..quadraticBezierTo(centerX - 10 * scale, bowlBottom + 15 * scale, centerX, bowlBottom + 18 * scale)
      ..quadraticBezierTo(centerX + 10 * scale, bowlBottom + 15 * scale, centerX + 8 * scale, bowlBottom - 2 * scale)
      ..close();
      
    final centerFootPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - 10 * scale, bowlBottom),
        Offset(centerX + 10 * scale, bowlBottom + 18 * scale),
        const [
          Color(0xFF5C2F15),
          Color(0xFFD4AF37),
          Color(0xFF3E2010),
        ],
      );
      
    canvas.drawPath(centerFoot, centerFootPaint);
    canvas.drawPath(centerFoot, footStroke);
  }

  void _drawBowl(Canvas canvas, Offset rimCenter, double bowlBottom, double scale) {
    // 3.1 Draw Bulbous Belly Body
    final body = Path()
      ..moveTo(rimCenter.dx - 45 * scale, rimCenter.dy)
      ..cubicTo(
        rimCenter.dx - 54 * scale, rimCenter.dy + 12 * scale,
        rimCenter.dx - 48 * scale, bowlBottom - 6 * scale,
        rimCenter.dx - 22 * scale, bowlBottom,
      )
      ..lineTo(rimCenter.dx + 22 * scale, bowlBottom)
      ..cubicTo(
        rimCenter.dx + 48 * scale, bowlBottom - 6 * scale,
        rimCenter.dx + 54 * scale, rimCenter.dy + 12 * scale,
        rimCenter.dx + 45 * scale, rimCenter.dy,
      )
      ..close();

    // Metallic gradient belly paint
    final bellyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(rimCenter.dx - 12 * scale, rimCenter.dy + 18 * scale),
        60 * scale,
        const [
          Color(0xFFFFF0B8), // Bright highlight
          Color(0xFFD4AF37), // Pure gold-bronze
          Color(0xFF8B5A2B), // Copper brown
          Color(0xFF3E2010), // Shadow brown
          Color(0xFF1B0C06), // Deep dark border
        ],
        const [0.0, 0.22, 0.55, 0.88, 1.0],
      );

    canvas.drawPath(body, bellyPaint);

    final bellyStroke = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale;
    canvas.drawPath(body, bellyStroke);

    // Decorative gold band around the neck
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
        ),
    );

    // 3.2 Draw Thick Rim (safely, proportionally scales to prevent negative height)
    final rimRect = Rect.fromCenter(
      center: rimCenter,
      width: 98 * scale,
      height: 16 * scale,
    );
    
    // Outer Rim
    canvas.drawOval(
      rimRect,
      Paint()
        ..shader = ui.Gradient.linear(
          rimRect.topLeft,
          rimRect.bottomRight,
          const [Color(0xFFFFD76B), Color(0xFF8B5A2B), Color(0xFFFFE08A)],
        ),
    );

    // Golden inner rim border
    canvas.drawOval(
      rimRect,
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );

    // Inner Rim opening (dark hole inside censer)
    final innerRimRect = Rect.fromCenter(
      center: rimCenter,
      width: rimRect.width * 0.90,
      height: rimRect.height * 0.85,
    );
    canvas.drawOval(
      innerRimRect,
      Paint()..color = const Color(0xFF200F07),
    );

    // Burning ash layers (proportional scaling is 100% safe from negative height crashes)
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
          const [
            Color(0xFF8A8279), // Light grey ash
            Color(0xFF4E463E), // Charcoal
            Color(0xFF251A12), // Outer ring
          ],
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
        ..shader = ui.Gradient.linear(base, tip, const [
          Color(0xFF4A1F0D),
          Color(0xFFC67735),
          Color(0xFFECC36C),
        ])
        ..strokeWidth = 3.0 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEmber(Canvas canvas, Offset tip, double scale) {
    canvas.drawCircle(
      tip,
      6.2 * scale,
      Paint()
        ..shader = ui.Gradient.radial(tip, 8.5 * scale, const [
          Color(0xFFFFF1A3),
          Color(0xFFFF5D00),
          Color(0x00FF5D00),
        ]),
    );
    canvas.drawCircle(
      tip,
      2.0 * scale,
      Paint()..color = const Color(0xFFFFFFFF),
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
    final verticalTitle = title.split('').join('\n');

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
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 10,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Core book background and traditional stitching
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ThreadBoundBookPainter(),
                    ),
                  ),

                  // 2. Vertical Ivory Label (书签)
                  Positioned(
                    left: 14,
                    top: 14,
                    bottom: 14,
                    width: 25,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFBF7),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: const Color(0xFF2C1E1A).withOpacity(0.4),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 2,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      child: Text(
                        verticalTitle,
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

    // 1. Base Indigo/Navy Paper Gradient
    final coverPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [
          Color(0xFF1C2C54), // Traditional deep indigo
          Color(0xFF0F1A35), // Indigo shadow
          Color(0xFF080E1E), // Deep dark spine edge
        ],
        const [0.0, 0.70, 1.0],
      );
    canvas.drawRRect(rrect, coverPaint);

    // 2. Gold border highlights
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [Color(0xFFFFD76B), Color(0xFF8B5A2B), Color(0xFFFFD76B)],
      );
    canvas.drawRRect(rrect.deflate(2.0), borderPaint);

    // 3. Traditional Stitched Threads on the right edge (Spine is on the right)
    final threadPaint = Paint()
      ..color = const Color(0xFFECC36C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double spineX = size.width - 8.0;
    
    // Vertical binding line
    canvas.drawLine(Offset(spineX, 0), Offset(spineX, size.height), threadPaint);

    // Stitch points and horizontal binding loops
    final double stitchOffset = 16.0;
    final int stitches = 6;
    final double step = (size.height - stitchOffset * 2) / (stitches - 1);
    
    for (int i = 0; i < stitches; i++) {
      final double y = stitchOffset + i * step;
      // Stitched loop going over the right spine edge
      canvas.drawLine(Offset(spineX, y), Offset(size.width, y), threadPaint);
      
      // Small needle hole dot
      canvas.drawCircle(Offset(spineX, y), 1.2, Paint()..color = const Color(0xFF3E2010));
      canvas.drawCircle(Offset(spineX, y), 0.7, Paint()..color = const Color(0xFFECC36C));
    }
    
    // Top & bottom diagonal spine corner stitches
    canvas.drawLine(Offset(spineX, stitchOffset), Offset(size.width - 2, 0), threadPaint);
    canvas.drawLine(Offset(spineX, size.height - stitchOffset), Offset(size.width - 2, size.height), threadPaint);

    // 4. Gold Corner Guards
    final cornerPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        const Offset(0, 0),
        12,
        const [Color(0xFFFFD76B), Color(0xFF8B5A2B)],
      );

    // Left corners (outer edges since spine is on the right)
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
