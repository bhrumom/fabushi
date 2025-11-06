import 'package:flutter/material.dart';

extension ContextSizeExtensions on BuildContext {
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;

  double h(double percentage) => height * (percentage / 100);
  double w(double percentage) => width * (percentage / 100);
  double sq(double size) => size;

  double fontSize(double size) => size;

  EdgeInsets paddingHorizontal(double padding) => EdgeInsets.symmetric(horizontal: padding);
  EdgeInsets paddingLeft(double padding) => EdgeInsets.only(left: padding);
  EdgeInsets paddingAll(double padding) => EdgeInsets.all(padding);
  BorderRadius radiusAll(double radius) => BorderRadius.circular(radius);
}
