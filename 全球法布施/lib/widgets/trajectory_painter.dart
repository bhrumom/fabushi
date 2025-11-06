import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as v;

class TrajectoryPoint {
  final v.Vector3 position;
  final double timestamp;

  TrajectoryPoint(this.position, this.timestamp);
}

class TrajectoryPainter extends CustomPainter {
  final double animationValue;
  final v.Vector3 start;
  final v.Vector3 end;
  final v.Vector3 control;
  final Color color;
  final int trailLength;
  final Function(v.Vector3, Size) projectToScreen;

  TrajectoryPainter({
    required this.animationValue,
    required this.start,
    required this.end,
    required this.control,
    required this.projectToScreen,
    this.color = Colors.cyan,
    this.trailLength = 15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue <= 0) return;

    // 计算当前彗星头部位置
    final currentPos = _getQuadraticBezierPoint(start, control, end, animationValue);
    final screenPos = projectToScreen(currentPos, size);

    // 绘制拖尾
    _drawTrail(canvas, size);

    // 绘制彗星头部
    _drawHead(canvas, screenPos);
  }

  void _drawTrail(Canvas canvas, Size size) {
    for (int i = 1; i <= trailLength; i++) {
      final t = animationValue - (i * 0.015);
      if (t < 0) break;

      final trailPos = _getQuadraticBezierPoint(start, control, end, t);
      final trailScreenPos = projectToScreen(trailPos, size);

      final opacity = 1.0 - (i / trailLength);
      final radius = 4.0 * opacity;

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawCircle(trailScreenPos, radius, paint);
    }
  }

  void _drawHead(Canvas canvas, Offset screenPos) {
    // 外层辉光
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(screenPos, 8.0, glowPaint);

    // 中层光晕
    final midPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(screenPos, 5.0, midPaint);

    // 核心亮点
    final corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(screenPos, 2.5, corePaint);
  }

  v.Vector3 _getQuadraticBezierPoint(v.Vector3 p0, v.Vector3 p1, v.Vector3 p2, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;

    return (p0 * uu) + (p1 * (2 * u * t)) + (p2 * tt);
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
