import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'meditation_room_painter.dart';
import 'sutra_dialog.dart';
import 'buddha_3d_widget.dart';

class MeditationRoom3DWidget extends StatefulWidget {
  const MeditationRoom3DWidget({Key? key}) : super(key: key);

  @override
  State<MeditationRoom3DWidget> createState() => _MeditationRoom3DWidgetState();
}

class _MeditationRoom3DWidgetState extends State<MeditationRoom3DWidget>
    with TickerProviderStateMixin {
  final List<String> _bookTitles = [
    '金刚经',
    '心经',
    '法华经',
    '华严经',
    '楞严经',
    '圆觉经',
    '维摩诘经',
    '地藏经',
  ];

  late AnimationController _glowController;
  late AnimationController _rotationController;
  double _cameraAngleX = 0.3;
  double _cameraAngleY = 0.0;
  double _cameraDistance = 8.0;

  // 供香和供灯状态
  bool _isIncenseOffering = false;
  bool _isLampOffering = false;
  int _incenseCount = 0;
  int _lampCount = 0;

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

  void _offerIncense() {
    setState(() {
      _isIncenseOffering = true;
      _incenseCount++;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isIncenseOffering = false);
      }
    });
  }

  void _offerLamp() {
    setState(() {
      _isLampOffering = true;
      _lampCount++;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isLampOffering = false);
      }
    });
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

  Widget _buildOfferingButton({
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.9)
              : Colors.brown[800]!.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isActive ? color : Colors.amber, width: 2),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 4),
              Text(
                '已供养 $count 次',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.brown[900]!, Colors.brown[700]!, Colors.brown[500]!],
        ),
      ),
      child: Stack(
        children: [
          if (kIsWeb)
            Center(
              child: SizedBox(width: 400, height: 500, child: Buddha3DWidget()),
            ),
          GestureDetector(
            onTapUp: (details) {
              final size = MediaQuery.of(context).size;
              _onSceneTap(details.localPosition, size);
            },
            onPanUpdate: (details) {
              setState(() {
                _cameraAngleY += details.delta.dx * 0.01;
                _cameraAngleX = (_cameraAngleX - details.delta.dy * 0.01).clamp(
                  -1.5,
                  1.5,
                );
              });
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _glowController,
                _rotationController,
              ]),
              builder: (context, child) {
                return SizedBox.expand(
                  child: CustomPaint(
                    painter: MeditationRoomPainter(
                      cameraAngleX: _cameraAngleX,
                      cameraAngleY: _cameraAngleY,
                      cameraDistance: _cameraDistance,
                      glowValue: _glowController.value,
                      rotationValue: _rotationController.value,
                      isIncenseOffering: _isIncenseOffering,
                      isLampOffering: _isLampOffering,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(
                        0.3 + _glowController.value * 0.2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withOpacity(
                          0.5 + _glowController.value * 0.5,
                        ),
                        width: 2,
                      ),
                    ),
                    child: const Text(
                      '🙏 点击经书阅读经文 🙏',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.amber, blurRadius: 10)],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // 供养按钮
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOfferingButton(
                  icon: Icons.spa,
                  label: '供香',
                  count: _incenseCount,
                  isActive: _isIncenseOffering,
                  onTap: _offerIncense,
                  color: Colors.grey[600]!,
                ),
                const SizedBox(width: 40),
                _buildOfferingButton(
                  icon: Icons.lightbulb,
                  label: '供灯',
                  count: _lampCount,
                  isActive: _isLampOffering,
                  onTap: _offerLamp,
                  color: Colors.orange[700]!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
