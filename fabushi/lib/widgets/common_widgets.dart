import 'package:flutter/material.dart';
import '../core/design_system/app_theme.dart';
import 'space_background.dart';

/// 渐变背景容器 (Now Space Background)
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(child: child);
  }
}

/// 统一的卡片容器 (Glassmorphism)
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool elevated;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.elevated = false,
  }) : super(key: key);

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(
      begin: widget.elevated ? 8.0 : 4.0,
      end: widget.elevated ? 12.0 : 8.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _elevationAnimation,
        builder: (context, child) => Container(
          decoration: AppTheme.glassDecoration,
          margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 主要操作按钮
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const PrimaryButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.icon != null
          ? FilledButton.icon(
              onPressed: widget.isLoading ? null : widget.onPressed,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(widget.icon),
              label: Text(widget.text),
              onHover: (hovering) {
                if (hovering) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
            )
          : FilledButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              onHover: (hovering) {
                if (hovering) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(widget.text),
            ),
    );
  }
}

/// 次要操作按钮
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
      );
    }

    return OutlinedButton(onPressed: onPressed, child: Text(text));
  }
}

/// 支付宝风格按钮
class AlipayButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool outlined;

  const AlipayButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.outlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.account_balance_wallet),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.alipayBlue,
          side: const BorderSide(color: AppTheme.alipayBlue, width: 2),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.account_balance_wallet),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.alipayBlue,
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// 信息展示卡片
class InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const InfoCard({
    Key? key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (iconColor ?? AppTheme.primaryColor).withOpacity(
            0.1,
          ),
          child: Icon(icon, color: iconColor ?? AppTheme.primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}

/// 统计数据卡片
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatCard({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppTheme.primaryColor;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: cardColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cardColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 空状态占位符
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.message,
    this.actionText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(text: actionText!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// 加载指示器
class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}

/// 会员徽章
class MembershipBadge extends StatelessWidget {
  final String text;
  final Color color;

  const MembershipBadge({Key? key, required this.text, required this.color})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分节标题
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2c3e50),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
