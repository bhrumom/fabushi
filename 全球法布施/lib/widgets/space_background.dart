import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/design_system/colors.dart';

class SpaceBackground extends StatelessWidget {
  final Widget child;

  const SpaceBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep Black Space Background
        Container(
          decoration: const BoxDecoration(
            color: Colors.black, // Base color is pure black
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                Color(0xFF0B1026), // Very dark blue, almost black
                Colors.black,      // Pure black
              ],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        
        // Star Field (Painted)
        const Positioned.fill(
          child: CustomPaint(
            painter: StarFieldPainter(),
          ),
        ),

        // Subtle Nebula Effect (Optional, kept very low opacity for depth)
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  nebulaPurple.withOpacity(0.1), // Reduced opacity
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        
        // Content
        child,
      ],
    );
  }
}

class StarFieldPainter extends CustomPainter {
  final math.Random _random = math.Random(42); // Fixed seed for consistent star positions

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white;
    
    // Draw background stars (small, numerous)
    for (int i = 0; i < 100; i++) {
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      final double radius = _random.nextDouble() * 1.5 + 0.5; // 0.5 to 2.0
      final double opacity = _random.nextDouble() * 0.6 + 0.2; // 0.2 to 0.8
      
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw bright stars (few, larger, some with cross flare hint if detailed, but circles are fine)
    for (int i = 0; i < 20; i++) {
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      final double radius = _random.nextDouble() * 1.0 + 1.5; // 1.5 to 2.5
      
      paint.color = Colors.white.withOpacity(0.9);
      
      // Draw core
      canvas.drawCircle(Offset(x, y), radius, paint);
      
      // Simple glow
      paint.color = Colors.white.withOpacity(0.3);
      canvas.drawCircle(Offset(x, y), radius * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // Stars are static
  }
}
