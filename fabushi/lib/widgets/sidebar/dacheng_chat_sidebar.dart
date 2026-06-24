import 'package:flutter/material.dart';

class DachengChatSidebar extends StatelessWidget {
  const DachengChatSidebar({
    super.key,
    required this.onNewChat,
    this.onClose,
    this.width,
  });

  final VoidCallback onNewChat;
  final VoidCallback? onClose;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final panelWidth = width ?? (media.width < 560 ? media.width * 0.9 : 360.0);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        right: false,
        child: Container(
          width: panelWidth.clamp(300.0, 420.0),
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1F2025),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '大乘',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: '关闭',
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFC7C7CB),
                          size: 34,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 62),
                _NewChatButton(onPressed: onNewChat),
                const SizedBox(height: 50),
                const Text(
                  '今天',
                  style: TextStyle(
                    color: Color(0xFF777981),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                const Center(
                  child: Text(
                    '没有更多内容啦',
                    style: TextStyle(
                      color: Color(0xFFBBBCC2),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_comment_outlined, size: 28),
        label: const Text(
          '开启新对话',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF30353A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
