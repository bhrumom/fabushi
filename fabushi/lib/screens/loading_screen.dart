import 'package:flutter/material.dart';

/// 轻量级加载屏幕
///
/// 在延迟加载(deferred loading)时显示,提供流畅的用户体验
/// 保持简单以最小化代码体积
class LoadingScreen extends StatelessWidget {
  final String? message;
  final bool showProgress;

  const LoadingScreen({super.key, this.message, this.showProgress = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 旋转的地球图标
              _buildGlobeIcon(),

              SizedBox(height: 32),

              // 加载文本
              Text(
                message ?? '正在加载...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),

              if (showProgress) ...[
                SizedBox(height: 24),
                _buildLoadingIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 旋转的地球图标
  Widget _buildGlobeIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(seconds: 2),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 2 * 3.14159, // 360度旋转
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.public,
              size: 48,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        );
      },
      onEnd: () {
        // 循环动画
      },
    );
  }

  /// 加载指示器
  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedDot(delay: Duration(milliseconds: index * 200));
      }),
    );
  }
}

/// 动画点
class AnimatedDot extends StatefulWidget {
  final Duration delay;

  const AnimatedDot({super.key, required this.delay});

  @override
  State<AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1400),
      vsync: this,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.8), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.7),
          ),
          transform: Matrix4.identity()..scale(_animation.value),
        );
      },
    );
  }
}

/// 带进度条的加载屏幕
class LoadingScreenWithProgress extends StatelessWidget {
  final String message;
  final double progress; // 0.0 - 1.0

  const LoadingScreenWithProgress({
    super.key,
    required this.message,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_download,
                  size: 64,
                  color: Colors.white.withOpacity(0.9),
                ),

                SizedBox(height: 32),

                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 24),

                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.9),
                    ),
                    minHeight: 8,
                  ),
                ),

                SizedBox(height: 12),

                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
