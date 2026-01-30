import 'package:flutter/material.dart';

/// 在线人数显示组件
/// 可复用的组件，支持不同的图标、文字前缀和活动类型
class OnlineCounterWidget extends StatelessWidget {
  final Stream<int> countStream;
  final int initialCount;
  final IconData icon;
  final String prefix;
  final Color? color;

  const OnlineCounterWidget({
    Key? key,
    required this.countStream,
    this.initialCount = 0,
    required this.icon,
    required this.prefix,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).primaryColor;

    return StreamBuilder<int>(
      stream: countStream,
      initialData: initialCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                displayColor.withOpacity(0.1),
                displayColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: displayColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: displayColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                prefix,
                style: TextStyle(
                  color: displayColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Text(
                  '$count',
                  key: ValueKey(count),
                  style: TextStyle(
                    color: displayColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '人',
                style: TextStyle(
                  color: displayColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 紧凑版在线人数显示（用于较小空间）
class CompactOnlineCounterWidget extends StatelessWidget {
  final Stream<int> countStream;
  final int initialCount;
  final IconData icon;
  final Color? color;

  const CompactOnlineCounterWidget({
    Key? key,
    required this.countStream,
    this.initialCount = 0,
    required this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).primaryColor;

    return StreamBuilder<int>(
      stream: countStream,
      initialData: initialCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: displayColor,
              size: 16,
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: Text(
                '$count',
                key: ValueKey(count),
                style: TextStyle(
                  color: displayColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
