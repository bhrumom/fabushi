import 'package:flutter/material.dart';
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
            color: Colors.black,
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [Color(0xFF0B1026), Colors.black],
              stops: [0.0, 1.0],
            ),
          ),
        ),

        // Subtle Nebula Effect
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [nebulaPurple.withOpacity(0.1), Colors.transparent],
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
