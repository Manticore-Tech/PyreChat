import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/appearance_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('appearance defaults to dynamic vivid background', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final appearance = AppearancePrefs(prefs: prefs);

    await appearance.load();

    expect(appearance.backgroundMode, PyreBackgroundMode.dynamic);
    expect(appearance.backgroundVisibility, 1.0);
  });

  test('appearance background and intensity persist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final appearance = AppearancePrefs(prefs: prefs);

    await appearance.setBackgroundMode(PyreBackgroundMode.sunset);
    await appearance.setBackgroundVisibility(0.65);

    final restored = AppearancePrefs(prefs: prefs);
    await restored.load();

    expect(restored.backgroundMode, PyreBackgroundMode.sunset);
    expect(restored.backgroundVisibility, closeTo(0.65, 0.001));
  });

  test('appearance reset restores PyreChat defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final appearance = AppearancePrefs(prefs: prefs);

    await appearance.setBackgroundMode(PyreBackgroundMode.ember);
    await appearance.setBackgroundVisibility(0.4);
    await appearance.reset();

    expect(appearance.backgroundMode, PyreBackgroundMode.dynamic);
    expect(appearance.backgroundVisibility, 1.0);
    expect(prefs.containsKey('appearance_background_mode'), isFalse);
    expect(prefs.containsKey('appearance_background_visibility'), isFalse);
  });
}
