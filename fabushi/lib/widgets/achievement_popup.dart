import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/achievement_system.dart';

/// 华丽成就动画弹窗
///
/// 特效包括：
/// - 金色粒子爆炸
/// - 渐变光晕扩散
/// - 图标放大弹跳
/// - 文字淡入滑动
class AchievementPopup extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onDismiss;
  final Duration displayDuration;

  const AchievementPopup({
    Key? key,
    required this.achievement,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 4),
  }) : super(key: key);

  @override
  State<AchievementPopup> createState() => _AchievementPopupState();

  /// 显示成就弹窗
  static void show(BuildContext context, Achievement achievement) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => AchievementPopup(
        achievement: achievement,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _AchievementPopupState extends State<AchievementPopup>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  late AnimationController _exitController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _iconBounceAnimation;
  late Animation<double> _glowAnimation;

  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _generateParticles();
    _startAnimations();
  }

  void _setupAnimations() {
    // 入场动画控制器
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 光晕循环控制器
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 粒子动画控制器
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 退出动画控制器
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 缩放动画（弹性效果）
    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );

    // 透明度动画
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5),
      ),
    );

    // 滑动动画
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutBack,
          ),
        );

    // 图标弹跳动画
    _iconBounceAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.8), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );

    // 光晕脉冲动画
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(_glowController);
  }

  void _generateParticles() {
    final tierColor = Color(widget.achievement.tierColor);

    for (int i = 0; i < 30; i++) {
      _particles.add(
        _Particle(
          x: 0.5,
          y: 0.5,
          vx: (_random.nextDouble() - 0.5) * 0.02,
          vy: (_random.nextDouble() - 0.5) * 0.02 - 0.005,
          size: _random.nextDouble() * 6 + 2,
          color: Color.lerp(
            tierColor,
            Colors.white,
            _random.nextDouble() * 0.5,
          )!,
          lifespan: _random.nextDouble() * 0.5 + 0.5,
        ),
      );
    }
  }

  void _startAnimations() {
    _entranceController.forward();
    _particleController.forward();

    // 设置自动关闭定时器
    _dismissTimer = Timer(widget.displayDuration, _dismiss);
  }

  void _dismiss() {
    _exitController.forward().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entranceController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _exitController]),
      builder: (context, child) {
        final exitValue = _exitController.value;
        final opacity = _opacityAnimation.value * (1 - exitValue);
        final scale = _scaleAnimation.value * (1 - exitValue * 0.3);

        if (opacity <= 0) return const SizedBox.shrink();

        return Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          left: 20,
          right: 20,
          child: SlideTransition(
            position: _slideAnimation,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: _buildCard()),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard() {
    final tierColor = Color(widget.achievement.tierColor);

    return GestureDetector(
      onTap: _dismiss,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 粒子层
          _buildParticles(),

          // 主卡片
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tierColor.withOpacity(0.9),
                      tierColor.withOpacity(0.7),
                      HSLColor.fromColor(
                        tierColor,
                      ).withLightness(0.3).toColor().withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withOpacity(0.5 * _glowAnimation.value),
                      blurRadius: 30 * _glowAnimation.value,
                      spreadRadius: 5 * _glowAnimation.value,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 图标
                    ScaleTransition(
                      scale: _iconBounceAnimation,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(
                                0.3 * _glowAnimation.value,
                              ),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.achievement.icon,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 文字内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '成就解锁',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  widget.achievement.tierName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.achievement.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.achievement.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _ParticlePainter(
            particles: _particles,
            progress: _particleController.value,
          ),
        );
      },
    );
  }
}

/// 粒子数据
class _Particle {
  double x, y;
  final double vx, vy;
  final double size;
  final Color color;
  final double lifespan;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.lifespan,
  });
}

/// 粒子绘制器
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // 计算当前位置
      final x = (particle.x + particle.vx * progress * 50) * size.width;
      final y = (particle.y + particle.vy * progress * 50) * size.height;

      // 计算透明度（基于寿命）
      final lifeProgress = progress / particle.lifespan;
      if (lifeProgress > 1) continue;

      final opacity = (1 - lifeProgress).clamp(0.0, 1.0);
      final currentSize = particle.size * (1 - lifeProgress * 0.5);

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), currentSize, paint);

      // 添加发光效果
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      canvas.drawCircle(Offset(x, y), currentSize * 1.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 成就监听组件
///
/// 将此组件放在Widget树顶层，自动监听并显示成就弹窗
class AchievementListener extends StatefulWidget {
  final Widget child;

  const AchievementListener({Key? key, required this.child}) : super(key: key);

  @override
  State<AchievementListener> createState() => _AchievementListenerState();
}

class _AchievementListenerState extends State<AchievementListener> {
  late StreamSubscription<Achievement> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AchievementSystem().achievementStream.listen((achievement) {
      if (mounted) {
        AchievementPopup.show(context, achievement);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
