import 'package:flutter/material.dart';

import '../screens/buddha_model_screen.dart';

class Buddha3DWidget extends StatelessWidget {
  final bool autoRotate;
  final bool isBurning;
  final double incenseProgress;
  final bool showBook;
  final String? bookTitle;
  final VoidCallback? onBookTap;
  final bool isVisible;

  const Buddha3DWidget({
    super.key,
    this.autoRotate = true,
    this.isBurning = false,
    this.incenseProgress = 0.0,
    this.showBook = false,
    this.bookTitle,
    this.onBookTap,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return BuddhaModelScreen(
      autoRotate: autoRotate,
      isBurning: isBurning,
      incenseProgress: incenseProgress,
      showBook: showBook,
      bookTitle: bookTitle,
      onBookTap: onBookTap,
      isVisible: isVisible,
    );
  }
}
