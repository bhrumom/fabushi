import 'package:flutter/material.dart';

import '../services/social_service.dart';

class FollowButton extends StatefulWidget {
  final String username;
  final bool initialIsFollowing;
  final bool isSelf;
  final int? initialFollowerCount;
  final bool dense;
  final VoidCallback? onChanged;

  const FollowButton({
    super.key,
    required this.username,
    this.initialIsFollowing = false,
    this.isSelf = false,
    this.initialFollowerCount,
    this.dense = true,
    this.onChanged,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _isFollowing;
  late int? _followerCount;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;
    _followerCount = widget.initialFollowerCount;
  }

  @override
  void didUpdateWidget(covariant FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username ||
        oldWidget.initialIsFollowing != widget.initialIsFollowing ||
        oldWidget.initialFollowerCount != widget.initialFollowerCount) {
      _isFollowing = widget.initialIsFollowing;
      _followerCount = widget.initialFollowerCount;
    }
  }

  Future<void> _toggle() async {
    if (_loading || widget.isSelf || widget.username.isEmpty) return;
    setState(() => _loading = true);

    final previousFollowing = _isFollowing;
    final previousCount = _followerCount;
    setState(() {
      _isFollowing = !_isFollowing;
      if (_followerCount != null) {
        _followerCount = (_followerCount! + (_isFollowing ? 1 : -1)).clamp(0, 1 << 31).toInt();
      }
    });

    try {
      final result = await SocialService().toggleFollow(widget.username);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _isFollowing = previousFollowing;
          _followerCount = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录后再关注')),
        );
        return;
      }

      setState(() {
        _isFollowing = result['isFollowing'] == true;
        final count = result['followerCount'];
        if (count is int) _followerCount = count;
      });
      widget.onChanged?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFollowing = previousFollowing;
        _followerCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('关注失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSelf) {
      return _buildSelfChip();
    }

    final label = _isFollowing ? '已关注' : '关注';
    final icon = _isFollowing ? Icons.check : Icons.add;
    final foreground = _isFollowing ? Colors.white70 : Colors.black;
    final background = _isFollowing ? Colors.white12 : const Color(0xFFD4AF37);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.dense ? 30 : 36,
          child: TextButton.icon(
            onPressed: _loading ? null : _toggle,
            style: TextButton.styleFrom(
              backgroundColor: background,
              disabledBackgroundColor: Colors.white10,
              foregroundColor: foreground,
              padding: EdgeInsets.symmetric(horizontal: widget.dense ? 10 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: _isFollowing ? Colors.white24 : Colors.transparent,
                ),
              ),
            ),
            icon: _loading
                ? SizedBox(
                    width: widget.dense ? 12 : 14,
                    height: widget.dense ? 12 : 14,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: widget.dense ? 14 : 16),
            label: Text(
              label,
              style: TextStyle(
                fontSize: widget.dense ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_followerCount != null) ...[
          const SizedBox(height: 3),
          Text(
            '$_followerCount 粉丝',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildSelfChip() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.dense ? 10 : 14,
        vertical: widget.dense ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        '自己',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
