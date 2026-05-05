import 'dart:math' as math;

import 'package:flutter/material.dart';

class StartupSplashScreen extends StatefulWidget {
  final String phaseLabel;

  const StartupSplashScreen({
    super.key,
    required this.phaseLabel,
  });

  @override
  State<StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<StartupSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
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
      builder: (context, _) {
        final pulse = 0.92 + math.sin(_controller.value * math.pi * 2) * 0.08;
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF140F1D),
                  Color(0xFF241812),
                  Color(0xFF09070B),
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: const Alignment(0, -0.24),
                  child: Container(
                    width: 320 * pulse,
                    height: 320 * pulse,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0x55FFE7A1).withOpacity(0.38),
                          const Color(0x22D4AF37),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 32,
                    ),
                    child: Column(
                      children: [
                        const Spacer(),
                        Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0x66FFE3A1),
                              width: 1.2,
                            ),
                            gradient: const RadialGradient(
                              colors: [
                                Color(0x33FFF0C7),
                                Color(0x11D4AF37),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x33D4AF37).withOpacity(0.45),
                                blurRadius: 28,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.self_improvement,
                            size: 54,
                            color: Color(0xFFFFE2A8),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          '大乘',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFE7B3),
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.phaseLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 188,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withOpacity(0.08),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.36 + (_controller.value * 0.48),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF2BF),
                                    Color(0xFFD4AF37),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '让首页先出现，把重资源留到后台慢慢安放。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
