import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/theme/pyre_scroll_behavior.dart';

void main() {
  test('desktop mouse drag participates in PyreChat page swipes', () {
    const behavior = PyreScrollBehavior();

    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
  });
}
