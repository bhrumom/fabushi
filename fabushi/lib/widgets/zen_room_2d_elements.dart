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
    final bowlTop = size.height - 52 * scale;
    final bowlBottom = size.height - 8 * scale;
    final rimCenter = Offset(centerX, bowlTop);
    final remaining = (1.0 - incenseProgress).clamp(0.18, 1.0).toDouble();
    final stickHeight = 78.0 * scale * remaining;

    _drawBowlShadow(canvas, centerX, bowlBottom, scale);
    _drawBowl(canvas, rimCenter, bowlBottom, scale);

    for (final dx in const [-11.0, 0.0, 11.0]) {
      final base = Offset(centerX + dx * scale, bowlTop - 4 * scale);
      final tip = base.translate(0, -stickHeight);
      _drawStick(canvas, base, tip, scale);
      if (isBurning) {
        _drawEmber(canvas, tip, scale);
      }
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
        center: Offset(centerX, bottom + 4 * scale),
        width: 104 * scale,
        height: 18 * scale,
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale),
    );
  }

  void _drawBowl(
    Canvas canvas,
    Offset rimCenter,
    double bowlBottom,
    double scale,
  ) {
    final rimRect = Rect.fromCenter(
      center: rimCenter,
      width: 106 * scale,
      height: 18 * scale,
    );
    final body = Path()
      ..moveTo(rimCenter.dx - 43 * scale, rimCenter.dy + 3 * scale)
      ..cubicTo(
        rimCenter.dx - 38 * scale,
        rimCenter.dy + 34 * scale,
        rimCenter.dx - 24 * scale,
        bowlBottom,
        rimCenter.dx,
        bowlBottom,
      )
      ..cubicTo(
        rimCenter.dx + 24 * scale,
        bowlBottom,
        rimCenter.dx + 38 * scale,
        rimCenter.dy + 34 * scale,
        rimCenter.dx + 43 * scale,
        rimCenter.dy + 3 * scale,
      )
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rimCenter.dx - 45 * scale, rimCenter.dy),
          Offset(rimCenter.dx + 45 * scale, bowlBottom),
          const [Color(0xFFD89236), Color(0xFF7B3A12), Color(0xFF2D1006)],
          const [0.0, 0.48, 1.0],
        ),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xB8D4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale,
    );

    canvas.drawOval(
      rimRect,
      Paint()
        ..shader = ui.Gradient.linear(
          rimRect.topLeft,
          rimRect.bottomRight,
          const [Color(0xFFFFD76B), Color(0xFF9C551F), Color(0xFFFFE08A)],
        ),
    );
    canvas.drawOval(
      rimRect.deflate(8 * scale),
      Paint()..color = const Color(0xFF2C1208),
    );
    canvas.drawOval(
      rimRect.deflate(16 * scale).translate(0, 1.4 * scale),
      Paint()..color = const Color(0xFF77604A),
    );

    final foot = Rect.fromCenter(
      center: Offset(rimCenter.dx, bowlBottom - 1 * scale),
      width: 48 * scale,
      height: 8 * scale,
    );
    canvas.drawOval(foot, Paint()..color = const Color(0xFF3A1609));
  }

  void _drawStick(Canvas canvas, Offset base, Offset tip, double scale) {
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = const Color(0xAA220C04)
        ..strokeWidth = 4.6 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..shader = ui.Gradient.linear(base, tip, const [
          Color(0xFF2F1307),
          Color(0xFFC47D34),
          Color(0xFFECC36C),
        ])
        ..strokeWidth = 2.4 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEmber(Canvas canvas, Offset tip, double scale) {
    canvas.drawCircle(
      tip,
      5.2 * scale,
      Paint()
        ..shader = ui.Gradient.radial(tip, 7.0 * scale, const [
          Color(0xFFFFF1A3),
          Color(0xFFFF6B1A),
          Color(0x00FF6B1A),
        ]),
    );
    canvas.drawCircle(
      tip,
      1.8 * scale,
      Paint()..color = const Color(0xFFFFE6A3),
    );
  }

  @override
  bool shouldRepaint(covariant IncenseOfferingPainter oldDelegate) {
    return oldDelegate.incenseProgress != incenseProgress ||
        oldDelegate.isBurning != isBurning;
  }
}

class SutraBookButton extends StatelessWidget {
  static const double baseWidth = 184;
  static const double baseHeight = 128;
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
            child: SizedBox(
              width: baseWidth,
              height: baseHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 18,
                    top: 28,
                    child: Transform.rotate(
                      angle: -0.08,
                      child: _BookPanel(
                        width: 78,
                        height: 68,
                        colors: const [
                          Color(0xFFFFF3C6),
                          Color(0xFFE4C26F),
                          Color(0xFF7A4A16),
                        ],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 28,
                    child: Transform.rotate(
                      angle: 0.08,
                      child: _BookPanel(
                        width: 78,
                        height: 68,
                        colors: const [
                          Color(0xFFFFF3C6),
                          Color(0xFFE4C26F),
                          Color(0xFF7A4A16),
                        ],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(8),
                          bottomLeft: Radius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 16,
                    child: Transform.rotate(
                      angle: -0.08,
                      child: _BookPanel(
                        width: 84,
                        height: 78,
                        colors: const [
                          Color(0xFFC0261E),
                          Color(0xFF6B0808),
                          Color(0xFF310303),
                        ],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 16,
                    child: Transform.rotate(
                      angle: 0.08,
                      child: _BookPanel(
                        width: 84,
                        height: 78,
                        colors: const [
                          Color(0xFFC0261E),
                          Color(0xFF6B0808),
                          Color(0xFF310303),
                        ],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(10),
                          bottomLeft: Radius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    bottom: 32,
                    child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 30,
                    right: 30,
                    top: 44,
                    child: Container(
                      height: 30,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x552A0202),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x66D4AF37)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFFFFE6A3),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    top: 16,
                    child: IgnorePointer(
                      child: Container(
                        height: 82,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 1.8,
                          ),
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

class _BookPanel extends StatelessWidget {
  final double width;
  final double height;
  final List<Color> colors;
  final BorderRadius borderRadius;

  const _BookPanel({
    required this.width,
    required this.height,
    required this.colors,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}
