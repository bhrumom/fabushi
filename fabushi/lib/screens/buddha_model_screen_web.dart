import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _incenseProgress = 0.0;
  bool _autoRotate = false;

  @override
  void initState() {
    super.initState();
    _incenseProgress = widget.incenseProgress;
    _autoRotate = widget.autoRotate;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.isVisible) _controller.repeat();
  }

  @override
  void didUpdateWidget(BuddhaModelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _incenseProgress = widget.incenseProgress;
    _autoRotate = widget.autoRotate;
    if (widget.isVisible && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isVisible && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void updateIncenseProgress(double progress) {
    if (!mounted) return;
    setState(() => _incenseProgress = progress);
  }

  void setAutoRotate(bool enabled) {
    setState(() => _autoRotate = enabled);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WebBuddhaRoomPainter(
                      tick: _controller.value,
                      autoRotate: _autoRotate,
                      isBurning: widget.isBurning,
                      incenseProgress: _incenseProgress,
                      showBook: widget.showBook,
                      bookTitle: widget.bookTitle,
                    ),
                  ),
                ),
                if (widget.showBook && widget.bookTitle != null)
                  Positioned(
                    left: (size.width - 184) / 2,
                    top: (size.height * 0.54)
                        .clamp(0.0, size.height - 270)
                        .toDouble(),
                    child: GestureDetector(
                      onTap: widget.onBookTap,
                      child: SizedBox(
                        width: 184,
                        height: 128,
                        child: CustomPaint(
                          painter: _WebSutraBookPainter(widget.bookTitle!),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WebBuddhaRoomPainter extends CustomPainter {
  final double tick;
  final bool autoRotate;
  final bool isBurning;
  final double incenseProgress;
  final bool showBook;
  final String? bookTitle;

  _WebBuddhaRoomPainter({
    required this.tick,
    required this.autoRotate,
    required this.isBurning,
    required this.incenseProgress,
    required this.showBook,
    required this.bookTitle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final floorCenter = Offset(center.dx, size.height * 0.76);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          const [Color(0xFF120C18), Color(0xFF26160F), Color(0xFF08060A)],
        ),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: floorCenter,
        width: size.width * 1.1,
        height: size.height * 0.34,
      ),
      Paint()
        ..shader = ui.Gradient.radial(floorCenter, size.width * 0.48, const [
          Color(0xFF5A351B),
          Color(0xFF1A0D08),
        ]),
    );

    _drawHalo(canvas, center.translate(0, -70), size);
    _drawBuddha(canvas, center.translate(0, -4), size);
    _drawIncense(canvas, Offset(center.dx, size.height * 0.82));
  }

  void _drawHalo(Canvas canvas, Offset center, Size size) {
    final pulse = 0.88 + math.sin(tick * math.pi * 2) * 0.08;
    for (var i = 4; i >= 0; i--) {
      canvas.drawCircle(
        center,
        (82 + i * 24) * pulse,
        Paint()
          ..color = Color.lerp(
            const Color(0x33FFF0A5),
            const Color(0x00D4AF37),
            i / 4,
          )!
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 + i * 8),
      );
    }
  }

  void _drawBuddha(Canvas canvas, Offset center, Size size) {
    final robePaint = Paint()
      ..shader = ui.Gradient.linear(
        center.translate(-70, -120),
        center.translate(70, 140),
        const [Color(0xFFFFE9A6), Color(0xFFD7A427), Color(0xFF7A4B0B)],
      );

    final body = Path()
      ..moveTo(center.dx, center.dy - 130)
      ..cubicTo(
        center.dx + 78,
        center.dy - 100,
        center.dx + 92,
        center.dy + 24,
        center.dx + 70,
        center.dy + 108,
      )
      ..lineTo(center.dx - 70, center.dy + 108)
      ..cubicTo(
        center.dx - 92,
        center.dy + 24,
        center.dx - 78,
        center.dy - 100,
        center.dx,
        center.dy - 130,
      )
      ..close();
    canvas.drawPath(body, robePaint);

    final headCenter = center.translate(0, -112);
    canvas.drawCircle(
      headCenter,
      44,
      Paint()
        ..shader = ui.Gradient.radial(
          headCenter.translate(-12, -16),
          58,
          const [Color(0xFFFFF2BD), Color(0xFFD7A427), Color(0xFF7A4B0B)],
        ),
    );
    canvas.drawCircle(
      headCenter.translate(0, -42),
      16,
      Paint()..color = const Color(0xFFC8921E),
    );

    final linePaint = Paint()
      ..color = const Color(0x667A4B0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: center.translate(0, -42 + i * 30),
          width: 132 - i * 6,
          height: 40,
        ),
        0.05,
        math.pi - 0.1,
        false,
        linePaint,
      );
    }

    _drawLotus(canvas, center.translate(0, 122));
  }

  void _drawLotus(Canvas canvas, Offset center) {
    final petalPaint = Paint()
      ..shader = ui.Gradient.radial(center, 70, const [
        Color(0xFFFFD7E4),
        Color(0xFFB24B72),
      ]);
    for (var i = 0; i < 10; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 5);
      canvas.drawOval(const Rect.fromLTWH(-13, -48, 26, 58), petalPaint);
      canvas.restore();
    }
  }

  void _drawIncense(Canvas canvas, Offset base) {
    final remaining = (1 - incenseProgress).clamp(0.16, 1.0).toDouble();
    final stickHeight = 74 * remaining;
    final offsets = [-13.0, 0.0, 13.0];
    _drawBurner(canvas, base);

    for (final dx in offsets) {
      final stickBase = base.translate(dx, -8);
      final tip = stickBase.translate(0, -stickHeight);
      canvas.drawLine(
        stickBase,
        tip,
        Paint()
          ..shader = ui.Gradient.linear(stickBase, tip, const [
            Color(0xFF3B1C0B),
            Color(0xFFC1843B),
          ])
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      if (isBurning) {
        canvas.drawCircle(
          tip,
          6,
          Paint()
            ..shader = ui.Gradient.radial(tip, 8, const [
              Color(0xFFFFF2B0),
              Color(0xFFFF5E1A),
              Color(0x00FF5E1A),
            ]),
        );
        _drawSmoke(canvas, tip, dx);
      }
    }
  }

  void _drawBurner(Canvas canvas, Offset center) {
    final body = Path()
      ..moveTo(center.dx - 54, center.dy)
      ..quadraticBezierTo(
        center.dx - 42,
        center.dy + 34,
        center.dx,
        center.dy + 42,
      )
      ..quadraticBezierTo(
        center.dx + 42,
        center.dy + 34,
        center.dx + 54,
        center.dy,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          center.translate(-54, 0),
          center.translate(54, 42),
          const [Color(0xFF3B1B0C), Color(0xFF9A5A24), Color(0xFF1E0C05)],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 112, height: 22),
      Paint()
        ..shader = ui.Gradient.linear(
          center.translate(-54, -8),
          center.translate(54, 8),
          const [Color(0xFFD4AF37), Color(0xFF4B210D), Color(0xFFFFD36A)],
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 86, height: 10),
      Paint()..color = const Color(0xFF25110A),
    );
  }

  void _drawSmoke(Canvas canvas, Offset tip, double seed) {
    for (var i = 0; i < 8; i++) {
      final t = (tick + i / 8 + seed * 0.01) % 1.0;
      final y = tip.dy - t * 112 - i * 4;
      final x = tip.dx + math.sin(t * math.pi * 2 + seed) * (8 + t * 28);
      final radius = 3 + t * 10;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.fromRGBO(235, 229, 214, (1 - t) * 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + t * 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WebBuddhaRoomPainter oldDelegate) => true;
}

class _WebSutraBookPainter extends CustomPainter {
  final String title;

  _WebSutraBookPainter(this.title);

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0x99000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.82),
        width: size.width * 0.78,
        height: 20,
      ),
      shadowPaint,
    );

    final coverPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.2, size.height * 0.12),
        Offset(size.width * 0.82, size.height * 0.7),
        const [Color(0xFFC0261E), Color(0xFF6B0808), Color(0xFF310303)],
      );
    final pagesPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.2, size.height * 0.22),
        Offset(size.width * 0.82, size.height * 0.74),
        const [Color(0xFFFFF2C4), Color(0xFFE0BC66), Color(0xFF80501A)],
      );

    final pages = Path()
      ..moveTo(size.width * 0.14, size.height * 0.32)
      ..lineTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.88, size.height * 0.32)
      ..lineTo(size.width * 0.86, size.height * 0.68)
      ..lineTo(size.width * 0.5, size.height * 0.78)
      ..lineTo(size.width * 0.14, size.height * 0.68)
      ..close();
    canvas.drawPath(pages, pagesPaint);

    final cover = Path()
      ..moveTo(size.width * 0.1, size.height * 0.24)
      ..lineTo(size.width * 0.5, size.height * 0.08)
      ..lineTo(size.width * 0.92, size.height * 0.24)
      ..lineTo(size.width * 0.9, size.height * 0.6)
      ..lineTo(size.width * 0.5, size.height * 0.72)
      ..lineTo(size.width * 0.1, size.height * 0.6)
      ..close();
    canvas.drawPath(cover, coverPaint);
    canvas.drawPath(
      cover,
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.72),
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = 1.4,
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFFFFE6A3),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    );
    titlePainter.layout(maxWidth: size.width * 0.72);
    titlePainter.paint(
      canvas,
      Offset((size.width - titlePainter.width) / 2, size.height * 0.39),
    );
  }

  @override
  bool shouldRepaint(covariant _WebSutraBookPainter oldDelegate) {
    return title != oldDelegate.title;
  }
}
