import 'dart:ui';

import 'package:flutter/material.dart';

/// PyreChat should feel equally direct on touchscreens, trackpads, and desktop
/// mice. Flutter intentionally disables mouse-drag scrolling by default on
/// desktop, which made the app's PageViews feel "stuck" on PC.
class PyreScrollBehavior extends MaterialScrollBehavior {
  const PyreScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
