import 'package:flutter/material.dart';

class TelegramSplitView extends StatefulWidget {
  const TelegramSplitView({
    super.key,
    required this.leftMenu,
    required this.rightContent,
    this.initialLeftWidth = 320.0,
    this.minLeftWidth = 260.0,
    this.maxLeftWidth = 480.0,
  });

  final Widget leftMenu;
  final Widget rightContent;
  final double initialLeftWidth;
  final double minLeftWidth;
  final double maxLeftWidth;

  @override
  State<TelegramSplitView> createState() => _TelegramSplitViewState();
}

class _TelegramSplitViewState extends State<TelegramSplitView> {
  late double _leftWidth;

  @override
  void initState() {
    super.initState();
    _leftWidth = widget.initialLeftWidth;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _leftWidth,
          child: widget.leftMenu,
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              setState(() {
                _leftWidth += details.delta.dx;
                if (_leftWidth < widget.minLeftWidth) {
                  _leftWidth = widget.minLeftWidth;
                } else if (_leftWidth > widget.maxLeftWidth) {
                  _leftWidth = widget.maxLeftWidth;
                }
              });
            },
            child: Container(
              width: 1, // Visual border width
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Color(0xFF223040), // Matches telegram chat list border
                    width: 1,
                  ),
                ),
              ),
              child: Container(
                width: 4, // Drag area hit box
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0E1621), // Chat background
            child: widget.rightContent,
          ),
        ),
      ],
    );
  }
}
