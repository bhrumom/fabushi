import 'package:flutter/material.dart';
import '../core/design_system/colors.dart';

class SpaceBackground extends StatelessWidget {
  final Widget child;

  const SpaceBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep Space Background
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.5, -0.5), // Top leftish
              radius: 1.5,
              colors: [
                Color(0xFF1A237E), // Deep Indigo
                spaceDeepBlue,     // Blackish
              ],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        // Nebula Effect 1
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  nebulaPurple.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Nebula Effect 2
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  nebulaPink.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Stars (Simple version using points or small containers)
        // ... (For now, we rely on the gradient depth, but we could add a StarField painter here)
        
        // Content
        child,
      ],
    );
  }
}
