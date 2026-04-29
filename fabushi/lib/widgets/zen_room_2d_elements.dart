import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class IncensePainter extends CustomPainter {
  final double incenseProgress;
  final bool isBurning;

  IncensePainter({
    required this.incenseProgress,
    required this.isBurning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    _drawFixedIncense(canvas, size);
  }

  void _drawFixedIncense(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.82);
    final remaining = (1.0 - incenseProgress).clamp(0.16, 1.0).toDouble();
    final stickHeight = 74.0 * remaining;
    _drawIncenseBurner(canvas, base, stickHeight);

    for (final offset in const [-14.0, 0.0, 14.0]) {
      final stickBase = base.translate(offset, -8);
      final stickTip = stickBase.translate(0, -stickHeight);
      canvas.drawLine(
        stickBase,
        stickTip,
        Paint()
          ..shader = ui.Gradient.linear(stickBase, stickTip, const [
            Color(0xFF5A2E16),
            Color(0xFFB07136),
            Color(0xFF2B1509),
          ])
          ..strokeWidth = 3.3
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
    final width = (stickHeight * 1.22).clamp(48.0, 88.0).toDouble();
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

class SutraBookButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const SutraBookButton({Key? key, required this.title, this.onTap}) : super(key: key);

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
          child: CustomPaint(painter: _SutraBookPainter(title)),
        ),
      ),
    );
  }
}

class _SutraBookPainter extends CustomPainter {
  final String title;

  _SutraBookPainter(this.title);

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

    final pagePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.26, size.height * 0.2),
        Offset(size.width * 0.74, size.height * 0.72),
        const [Color(0xFFFFF3C6), Color(0xFFE4C26F), Color(0xFF7A4A16)],
        const [0.0, 0.54, 1.0],
      );
    final coverPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.2, size.height * 0.12),
        Offset(size.width * 0.82, size.height * 0.7),
        const [Color(0xFF9E1C16), Color(0xFF5E0707), Color(0xFF2A0202)],
      );
    final rightCoverPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.46, size.height * 0.1),
        Offset(size.width * 0.9, size.height * 0.66),
        const [Color(0xFFC0261E), Color(0xFF6B0808), Color(0xFF310303)],
      );

    final leftPages = Path()
      ..moveTo(size.width * 0.15, size.height * 0.32)
      ..lineTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.5, size.height * 0.78)
      ..lineTo(size.width * 0.14, size.height * 0.68)
      ..close();
    final rightPages = Path()
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.88, size.height * 0.32)
      ..lineTo(size.width * 0.86, size.height * 0.68)
      ..lineTo(size.width * 0.5, size.height * 0.78)
      ..close();

    canvas.drawPath(leftPages, pagePaint);
    canvas.drawPath(rightPages, pagePaint);

    final leftCover = Path()
      ..moveTo(size.width * 0.09, size.height * 0.24)
      ..lineTo(size.width * 0.49, size.height * 0.09)
      ..lineTo(size.width * 0.5, size.height * 0.72)
      ..lineTo(size.width * 0.1, size.height * 0.59)
      ..close();
    final rightCover = Path()
      ..moveTo(size.width * 0.51, size.height * 0.09)
      ..lineTo(size.width * 0.93, size.height * 0.25)
      ..lineTo(size.width * 0.9, size.height * 0.6)
      ..lineTo(size.width * 0.5, size.height * 0.72)
      ..close();
    canvas.drawPath(leftCover, coverPaint);
    canvas.drawPath(rightCover, rightCoverPaint);

    final goldLine = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(leftCover, goldLine);
    canvas.drawPath(rightCover, goldLine);
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.74),
      Paint()
        ..color = const Color(0xAA3A1204)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.12),
      Offset(size.width * 0.5, size.height * 0.71),
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    final pageLine = Paint()
      ..color = const Color(0x887A4A16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.34 + i * 0.065);
      canvas.drawLine(
        Offset(size.width * 0.2, y + i * 1.5),
        Offset(size.width * 0.43, y - 8),
        pageLine,
      );
      canvas.drawLine(
        Offset(size.width * 0.57, y - 8),
        Offset(size.width * 0.82, y + i * 1.4),
        pageLine,
      );
    }

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFFFFE6A3),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          shadows: [Shadow(color: Color(0xFF3A1204), blurRadius: 4)],
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
      Offset((size.width - titlePainter.width) / 2, size.height * 0.37),
    );

    final hintPainter = TextPainter(
      text: const TextSpan(
        text: '经卷',
        style: TextStyle(color: Color(0xCCFFF4C2), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    hintPainter.layout();
    hintPainter.paint(
      canvas,
      Offset((size.width - hintPainter.width) / 2, size.height * 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _SutraBookPainter oldDelegate) {
    return title != oldDelegate.title;
  }
}
