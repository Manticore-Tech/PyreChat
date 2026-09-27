import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PyreBackgroundMode {
  dynamic,
  night,
  sunset,
  ember,
}

extension PyreBackgroundModeLabel on PyreBackgroundMode {
  String get label => switch (this) {
        PyreBackgroundMode.dynamic => 'Dynamic',
        PyreBackgroundMode.night => 'Night',
        PyreBackgroundMode.sunset => 'Sunset',
        PyreBackgroundMode.ember => 'Embers',
      };

  String get description => switch (this) {
        PyreBackgroundMode.dynamic =>
          'PyreChat chooses the scene that fits each screen.',
        PyreBackgroundMode.night => 'Keep the app in the deep blue night scene.',
        PyreBackgroundMode.sunset =>
          'Use the warm mountain sunset throughout the app.',
        PyreBackgroundMode.ember =>
          'Use the darker ember-and-fire atmosphere throughout the app.',
      };
}

class AppearancePrefs extends ChangeNotifier {
  AppearancePrefs({SharedPreferences? prefs}) : _prefs = prefs;

  static final AppearancePrefs instance = AppearancePrefs();

  static const _backgroundKey = 'appearance_background_mode';
  static const _visibilityKey = 'appearance_background_visibility';

  SharedPreferences? _prefs;
  PyreBackgroundMode _backgroundMode = PyreBackgroundMode.dynamic;
  double _backgroundVisibility = 1.0;

  PyreBackgroundMode get backgroundMode => _backgroundMode;
  double get backgroundVisibility => _backgroundVisibility;

  Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> load() async {
    final prefs = await _preferences();
    final savedMode = prefs.getString(_backgroundKey);
    _backgroundMode = PyreBackgroundMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => PyreBackgroundMode.dynamic,
    );
    _backgroundVisibility =
        (prefs.getDouble(_visibilityKey) ?? 1.0).clamp(0.35, 1.0).toDouble();
    notifyListeners();
  }

  Future<void> setBackgroundMode(PyreBackgroundMode mode) async {
    if (_backgroundMode == mode) return;
    _backgroundMode = mode;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.setString(_backgroundKey, mode.name);
  }

  Future<void> setBackgroundVisibility(double value) async {
    final clamped = value.clamp(0.35, 1.0).toDouble();
    if ((_backgroundVisibility - clamped).abs() < 0.001) return;
    _backgroundVisibility = clamped;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.setDouble(_visibilityKey, clamped);
  }

  Future<void> reset() async {
    _backgroundMode = PyreBackgroundMode.dynamic;
    _backgroundVisibility = 1.0;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.remove(_backgroundKey);
    await prefs.remove(_visibilityKey);
  }
}
