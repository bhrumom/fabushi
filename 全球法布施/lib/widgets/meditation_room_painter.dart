import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MeditationRoomPainter extends CustomPainter {
  final double cameraAngleX;
  final double cameraAngleY;
  final double cameraDistance;
  final double glowValue;
  final double rotationValue;
  final bool isIncenseOffering;
  final bool isLampOffering;

  MeditationRoomPainter({
    required this.cameraAngleX,
    required this.cameraAngleY,
    required this.cameraDistance,
    required this.glowValue,
    required this.rotationValue,
    this.isIncenseOffering = false,
    this.isLampOffering = false,
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
    
    // 绘制佛像（使用3D模型数据渲染）
    _drawBuddhaModel(canvas, center);
    
    // 绘制供香效果
    if (isIncenseOffering) {
      _drawIncenseSmoke(canvas, center);
    }
    
    // 绘制供灯效果
    if (isLampOffering) {
      _drawLampLight(canvas, center);
    }
    
    // 绘制经书
    _drawSimpleBooks(canvas, center);
  }

  void _drawBuddhaModel(Canvas canvas, Offset center) {
    final buddhaCenter = Offset(center.dx, center.dy - 30);
    
    // 大光环背景
    for (int i = 5; i >= 0; i--) {
      final glowPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFD700),
          const Color(0xFFFFE4B5),
          i / 5,
        )!.withOpacity((0.15 - i * 0.02) * (0.8 + glowValue * 0.2))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20.0 + i * 8);
      canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 100), 120 + i * 25, glowPaint);
    }
    
    // 佛像身体（立体效果）
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(buddhaCenter.dx - 60, buddhaCenter.dy - 100),
        Offset(buddhaCenter.dx + 60, buddhaCenter.dy + 100),
        [
          const Color(0xFFFFE4B5),
          const Color(0xFFFFD700),
          const Color(0xFFB8860B),
          const Color(0xFFFFD700),
        ],
      );
    
    // 身体主体
    final bodyPath = Path()
      ..moveTo(buddhaCenter.dx, buddhaCenter.dy - 120)
      ..quadraticBezierTo(
        buddhaCenter.dx + 70, buddhaCenter.dy - 80,
        buddhaCenter.dx + 80, buddhaCenter.dy,
      )
      ..quadraticBezierTo(
        buddhaCenter.dx + 90, buddhaCenter.dy + 60,
        buddhaCenter.dx + 60, buddhaCenter.dy + 100,
      )
      ..lineTo(buddhaCenter.dx - 60, buddhaCenter.dy + 100)
      ..quadraticBezierTo(
        buddhaCenter.dx - 90, buddhaCenter.dy + 60,
        buddhaCenter.dx - 80, buddhaCenter.dy,
      )
      ..quadraticBezierTo(
        buddhaCenter.dx - 70, buddhaCenter.dy - 80,
        buddhaCenter.dx, buddhaCenter.dy - 120,
      );
    canvas.drawPath(bodyPath, bodyPaint);
    
    // 衣服纹理
    final detailPaint = Paint()
      ..color = const Color(0xFFB8860B).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      final y = buddhaCenter.dy - 60 + i * 30;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(buddhaCenter.dx, y), width: 120, height: 40),
        0,
        math.pi,
        false,
        detailPaint,
      );
    }
    
    // 佛像头部（立体效果）
    final headPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(buddhaCenter.dx, buddhaCenter.dy - 100),
        50,
        [
          const Color(0xFFFFE4B5),
          const Color(0xFFFFD700),
          const Color(0xFFB8860B),
        ],
      );
    canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 100), 50, headPaint);
    
    // 肉髻
    final ushnishaPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(buddhaCenter.dx, buddhaCenter.dy - 140),
        20,
        [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      );
    canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 140), 20, ushnishaPaint);
    
    // 眼睛
    final eyePaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawCircle(Offset(buddhaCenter.dx - 15, buddhaCenter.dy - 105), 3, eyePaint);
    canvas.drawCircle(Offset(buddhaCenter.dx + 15, buddhaCenter.dy - 105), 3, eyePaint);
    
    // 光环主圈
    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(buddhaCenter.dx, buddhaCenter.dy - 100),
        90,
        [
          const Color(0xFFFFFFFF).withOpacity(0.9),
          const Color(0xFFFFD700).withOpacity(0.5),
          const Color(0xFFFFD700).withOpacity(0.0),
        ],
      );
    canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 100), 90, haloPaint);
    
    // 光环边缘
    final ringPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(buddhaCenter.dx, buddhaCenter.dy - 100), 85, ringPaint);
    
    // 莲花座
    _drawLotusBase(canvas, Offset(buddhaCenter.dx, buddhaCenter.dy + 110));
  }
  
  void _drawLotusBase(Canvas canvas, Offset center) {
    final lotusPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        60,
        [const Color(0xFFFFB6C1), const Color(0xFFFF69B4)],
      );
    
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        const Rect.fromLTWH(-15, -50, 30, 60),
        lotusPaint,
      );
      canvas.restore();
    }
  }
  
  void _drawIncenseSmoke(Canvas canvas, Offset center) {
    final smokeCenter = Offset(center.dx - 80, center.dy + 50);
    
    for (int i = 0; i < 5; i++) {
      final offset = i * 30.0;
      final opacity = (1.0 - i / 5) * 0.5;
      final smokePaint = Paint()
        ..color = Colors.grey.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 + i * 2);
      
      canvas.drawCircle(
        Offset(smokeCenter.dx + math.sin(offset * 0.1) * 10, smokeCenter.dy - offset),
        15 + i * 3,
        smokePaint,
      );
    }
    
    // 香炉
    final incensePaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: smokeCenter, width: 40, height: 30),
        const Radius.circular(5),
      ),
      incensePaint,
    );
  }
  
  void _drawLampLight(Canvas canvas, Offset center) {
    final lampCenter = Offset(center.dx + 80, center.dy + 50);
    
    // 灯光效果
    for (int i = 3; i >= 0; i--) {
      final lightPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFD700),
          const Color(0xFFFF6347),
          i / 3,
        )!.withOpacity((0.3 - i * 0.05) * (0.8 + glowValue * 0.2))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20.0 + i * 5);
      canvas.drawCircle(lampCenter, 40 + i * 10, lightPaint);
    }
    
    // 灯座
    final lampPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(lampCenter.dx, lampCenter.dy - 20),
        Offset(lampCenter.dx, lampCenter.dy + 20),
        [const Color(0xFFB8860B), const Color(0xFFFFD700)],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: lampCenter, width: 30, height: 40),
        const Radius.circular(5),
      ),
      lampPaint,
    );
    
    // 火焰
    final flamePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(lampCenter.dx, lampCenter.dy - 30),
        Offset(lampCenter.dx, lampCenter.dy - 10),
        [const Color(0xFFFFFF00), const Color(0xFFFF6347)],
      );
    final flamePath = Path()
      ..moveTo(lampCenter.dx, lampCenter.dy - 30)
      ..quadraticBezierTo(
        lampCenter.dx + 8, lampCenter.dy - 20,
        lampCenter.dx, lampCenter.dy - 10,
      )
      ..quadraticBezierTo(
        lampCenter.dx - 8, lampCenter.dy - 20,
        lampCenter.dx, lampCenter.dy - 30,
      );
    canvas.drawPath(flamePath, flamePaint);
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
