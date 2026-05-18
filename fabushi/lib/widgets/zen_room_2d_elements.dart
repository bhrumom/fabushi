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
    final remaining = (1.0 - incenseProgress).clamp(0.16, 1.0).toDouble();
    final stickHeight = 88.0 * remaining;
    const centerX = 85.0;
    final flameBottom = 58.0 + stickHeight - 6.0;

    return SizedBox.expand(
      child: Center(
        child: SizedBox(
          width: 170,
          height: 196,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 4,
                child: Container(
                  width: 124,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    borderRadius: BorderRadius.all(Radius.elliptical(62, 11)),
                    boxShadow: [
                      BoxShadow(color: Color(0x99000000), blurRadius: 14),
                    ],
                  ),
                ),
              ),
              for (final dx in const [-18.0, 0.0, 18.0]) ...[
                Positioned(
                  left: centerX + dx - 3,
                  bottom: 58,
                  child: Container(
                    width: 6,
                    height: stickHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFF2B1509),
                          Color(0xFFE7B45F),
                          Color(0xFF5A2E16),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0xAA000000), blurRadius: 5),
                      ],
                    ),
                  ),
                ),
                if (isBurning) ...[
                  Positioned(
                    left: centerX + dx - 9,
                    bottom: flameBottom,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFFFFF1A3),
                            Color(0xFFFF6B1A),
                            Color(0x00FF6B1A),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      left: centerX + dx - 7 + (i.isEven ? -8 : 8),
                      bottom: flameBottom + 22 + i * 24,
                      child: Container(
                        width: 14.0 + i * 6,
                        height: 14.0 + i * 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromRGBO(235, 229, 214, 0.16 - i * 0.03),
                          boxShadow: const [
                            BoxShadow(color: Color(0x66EDE5D8), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
              Positioned(
                bottom: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFD4AF37),
                            Color(0xFF6F3514),
                            Color(0xFFFFD36A),
                          ],
                        ),
                        border: Border.all(color: const Color(0x99D4AF37)),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -4),
                      child: Container(
                        width: 94,
                        height: 34,
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(38),
                            top: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF9A5A24),
                              Color(0xFF4A2111),
                              Color(0xFF2A1208),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(color: Color(0x99000000), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SutraBookButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const SutraBookButton({super.key, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: title,
        child: SizedBox(
          width: 184,
          height: 128,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 22,
                right: 22,
                bottom: 8,
                child: Container(
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    borderRadius: BorderRadius.all(Radius.elliptical(70, 9)),
                    boxShadow: [
                      BoxShadow(color: Color(0x99000000), blurRadius: 14),
                    ],
                  ),
                ),
              ),
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
                    boxShadow: const [
                      BoxShadow(color: Color(0xAA3A1204), blurRadius: 5),
                    ],
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
                        shadows: [
                          Shadow(color: Color(0xFF3A1204), blurRadius: 4),
                        ],
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
