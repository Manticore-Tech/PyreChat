import 'package:flutter/animation.dart';

abstract final class PyreMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);

  static const enter = Curves.easeOutCubic;
  static const settle = Curves.easeOutQuart;
}
