import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 200);
  static const emphasis = Duration(milliseconds: 250);
  static const container = Duration(milliseconds: 300);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const standardCurve = Curves.easeInOutCubic;
}
