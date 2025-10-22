import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'meditation_room_painter.dart';
import 'sutra_dialog.dart';

class MeditationRoom3DWidget extends StatefulWidget {
  const MeditationRoom3DWidget({Key? key}) : super(key: key);

  @override
  State<MeditationRoom3DWidget> createState() => _MeditationRoom3DWidgetState();
}

class _MeditationRoom3DWidgetState extends State<MeditationRoom3DWidget> with TickerProviderStateMixin {
  final List<String> _bookTitles = [
    '金刚经', '心经', '法华经', '华严经',
    '楞严经', '圆觉经', '维摩诘经', '地藏经'
  ];
  
  late AnimationController _glowController;
  late AnimationController _rotationController;
  double _cameraAngleX = 0.3;
  double _cameraAngleY = 0.0;
  double _cameraDistance = 8.0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }



  void _onSceneTap(Offset position, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance > 80 && distance < 200) {
      final angle = math.atan2(dx, -dy);
      var bookIndex = ((angle + math.pi) / (math.pi / 4)).round() % 8;
      bookIndex = bookIndex.clamp(0, _bookTitles.length - 1);
      _showSutraDialog(_bookTitles[bookIndex]);
    }
  }

  void _showSutraDialog(String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => SutraDialog(title: title),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.brown[900]!,
            Colors.brown[700]!,
            Colors.brown[500]!,
          ],
        ),
      ),
      child: Stack(
        children: [
          GestureDetector(
            onTapUp: (details) {
              final size = MediaQuery.of(context).size;
              _onSceneTap(details.localPosition, size);
            },
            onPanUpdate: (details) {
              setState(() {
                _cameraAngleY += details.delta.dx * 0.01;
                _cameraAngleX = (_cameraAngleX - details.delta.dy * 0.01).clamp(-1.5, 1.5);
              });
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_glowController, _rotationController]),
              builder: (context, child) {
                return SizedBox.expand(
                  child: CustomPaint(
                    painter: MeditationRoomPainter(
                      cameraAngleX: _cameraAngleX,
                      cameraAngleY: _cameraAngleY,
                      cameraDistance: _cameraDistance,
                      glowValue: _glowController.value,
                      rotationValue: _rotationController.value,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3 + _glowController.value * 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.5 + _glowController.value * 0.5),
                        width: 2,
                      ),
                    ),
                    child: const Text(
                      '🙏 点击经书阅读经文 🙏',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.amber, blurRadius: 10),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
