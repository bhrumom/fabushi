import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MeditationRoomPainter extends CustomPainter {
  final double cameraAngleX;
  final double cameraAngleY;
  final double cameraDistance;
  final double glowValue;
  final double rotationValue;

  MeditationRoomPainter({
    required this.cameraAngleX,
    required this.cameraAngleY,
    required this.cameraDistance,
    required this.glowValue,
    required this.rotationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 绘制地面
    final floorPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        300,
        [const Color(0xFF654321), const Color(0xFF3E2723)],
      );
    canvas.drawCircle(center, 300, floorPaint);
    
    // 绘制佛像
    _drawSimpleBuddha(canvas, center);
    
    // 绘制经书
    _drawSimpleBooks(canvas, center);
  }

  void _drawSimpleBuddha(Canvas canvas, Offset center) {
    final buddhaCenter = Offset(center.dx, center.dy - 50);
    
    // 佛像身体（金色椭圆）
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(buddhaCenter.dx, buddhaCenter.dy - 80),
        Offset(buddhaCenter.dx, buddhaCenter.dy + 80),
        [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      );
    canvas.drawOval(
      Rect.fromCenter(center: buddhaCenter, width: 120, height: 200),
      bodyPaint,
    );
    
    // 佛像头部
    final headPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(buddhaCenter.dx, buddhaCenter.dy - 80),
        40,
        [const Color(0xFFFFE4B5), const Color(0xFFFFD700)],
      );
    canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 80), 40, headPaint);
    
    // 光环
    for (int i = 3; i >= 0; i--) {
      final glowPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFD700),
          const Color(0xFFFFE4B5),
          i / 3,
        )!.withOpacity((0.2 - i * 0.05) * (0.7 + glowValue * 0.3))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15.0 + i * 5);
      canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 130), 80 + i * 15, glowPaint);
    }
    
    // 光环主圈
    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(buddhaCenter.dx, buddhaCenter.dy - 130),
        70,
        [
          const Color(0xFFFFFFFF).withOpacity(0.9),
          const Color(0xFFFFD700).withOpacity(0.0),
        ],
      );
    canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 130), 70, haloPaint);
    
    // 光环边缘
    final ringPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 130), 65, ringPaint);
  }

  void _drawSimpleBooks(Canvas canvas, Offset center) {
    final bookColors = [
      Colors.red[900]!,
      Colors.blue[900]!,
      Colors.green[900]!,
      Colors.purple[900]!,
      Colors.orange[900]!,
      Colors.teal[900]!,
      Colors.indigo[900]!,
      Colors.brown[900]!,
    ];
    
    final bookTitles = [
      '金刚经', '心经', '法华经', '华严经',
      '楞严经', '圆觉经', '维摩诘经', '地藏经'
    ];
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 + rotationValue * 360) * math.pi / 180;
      final radius = 180.0;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius * 0.5 + 100;
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);
      
      // 书的主体
      final bookPaint = Paint()..color = bookColors[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-25, -35, 50, 70),
          const Radius.circular(4),
        ),
        bookPaint,
      );
      
      // 书的边框
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-23, -33, 46, 66),
          const Radius.circular(4),
        ),
        borderPaint,
      );
      
      // 书名
      final textPainter = TextPainter(
        text: TextSpan(
          text: bookTitles[i],
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(MeditationRoomPainter oldDelegate) => true;
}
