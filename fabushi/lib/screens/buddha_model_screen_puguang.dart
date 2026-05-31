import 'package:flutter/material.dart';

class BuddhaModelScreen extends StatelessWidget {
  final bool autoRotate;
  final bool isBurning;
  final double incenseProgress;
  final bool showBook;
  final String? bookTitle;
  final VoidCallback? onBookTap;
  final bool isVisible;

  const BuddhaModelScreen({
    super.key,
    this.autoRotate = false,
    this.isBurning = false,
    this.incenseProgress = 0,
    this.showBook = false,
    this.bookTitle,
    this.onBookTap,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFF120B08));
  }
}
