import 'package:flutter/material.dart';
import 'dart:math' as math;

class MeteorBeam {
  final Offset start;
  final Offset end;
  final Color color;
  final double progress;
  
  MeteorBeam({
    required this.start,
    required this.end,
    required this.color,
    required this.progress,
  });
}

class MeteorBeamPainter extends CustomPainter {
  final List<MeteorBeam> beams;
  
  MeteorBeamPainter(this.beams);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var beam in beams) {
      _drawMeteor(canvas, beam);
    }
  }
  
  void _drawMeteor(Canvas canvas, MeteorBeam beam) {
    if (beam.progress <= 0) return;
    
    final currentPos = Offset.lerp(beam.start, beam.end, beam.progress)!;
    final tailLength = 0.15;
    final tailStart = math.max(0.0, beam.progress - tailLength);
    final tailPos = Offset.lerp(beam.start, beam.end, tailStart)!;
    
    // 绘制拖尾渐变
    final gradient = LinearGradient(
      colors: [
        beam.color.withAlpha(0),
        beam.color.withAlpha(100),
        beam.color.withAlpha(255),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromPoints(tailPos, currentPos))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(tailPos, currentPos, paint);
    
    // 绘制光点
    final glowPaint = Paint()
      ..color = beam.color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(currentPos, 4, glowPaint);
    canvas.drawCircle(currentPos, 2, Paint()..color = Colors.white);
  }
  
  @override
  bool shouldRepaint(MeteorBeamPainter oldDelegate) => true;
}
