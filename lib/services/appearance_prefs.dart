import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/services/local_image_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PyreBackgroundMode {
  dynamic,
  night,
  sunset,
  ember,
  custom,
}

extension PyreBackgroundModeLabel on PyreBackgroundMode {
  String get label => switch (this) {
        PyreBackgroundMode.dynamic => 'Dynamic',
        PyreBackgroundMode.night => 'Night',
        PyreBackgroundMode.sunset => 'Sunset',
        PyreBackgroundMode.ember => 'Embers',
        PyreBackgroundMode.custom => 'Custom',
      };

  String get description => switch (this) {
        PyreBackgroundMode.dynamic =>
          'PyreChat chooses the scene that fits each screen.',
        PyreBackgroundMode.night => 'Keep the app in the deep blue night scene.',
        PyreBackgroundMode.sunset =>
          'Use the warm mountain sunset throughout the app.',
        PyreBackgroundMode.ember =>
          'Use the darker ember-and-fire atmosphere throughout the app.',
        PyreBackgroundMode.custom =>
          'Use your own photo as the signed-in app background.',
      };
}

class AppearancePrefs extends ChangeNotifier {
  AppearancePrefs({SharedPreferences? prefs}) : _prefs = prefs;

  static final AppearancePrefs instance = AppearancePrefs();

  static const _backgroundKey = 'appearance_background_mode';
  static const _visibilityKey = 'appearance_background_visibility';
  static const _customBackgroundPathKey = 'appearance_custom_background_path';
  static const _accentHueKey = 'appearance_accent_hue';
  static const _accentSaturationKey = 'appearance_accent_saturation';
  static const _accentValueKey = 'appearance_accent_value';
  static const _glassStrengthKey = 'appearance_glass_strength';
  static const _backgroundBlurKey = 'appearance_background_blur';

  SharedPreferences? _prefs;
  PyreBackgroundMode _backgroundMode = PyreBackgroundMode.dynamic;
  double _backgroundVisibility = 1.0;
  String? _customBackgroundPath;
  Uint8List? _customBackgroundBytes;
  double _accentHue = 24;
  double _accentSaturation = 0.78;
  double _accentValue = 1.0;
  double _glassStrength = 1.0;
  double _backgroundBlur = 0;

  PyreBackgroundMode get backgroundMode => _backgroundMode;
  double get backgroundVisibility => _backgroundVisibility;
  String? get customBackgroundPath => _customBackgroundPath;
  Uint8List? get customBackgroundBytes => _customBackgroundBytes;
  bool get hasCustomBackground =>
      _customBackgroundBytes != null && _customBackgroundBytes!.isNotEmpty;
  double get accentHue => _accentHue;
  double get accentSaturation => _accentSaturation;
  double get accentValue => _accentValue;
  double get glassStrength => _glassStrength;
  double get backgroundBlur => _backgroundBlur;

  Color get accentColor => HSVColor.fromAHSV(
        1,
        _accentHue,
        _accentSaturation,
        _accentValue,
      ).toColor();

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
    _accentHue =
        (prefs.getDouble(_accentHueKey) ?? 24).clamp(0, 360).toDouble();
    _accentSaturation =
        (prefs.getDouble(_accentSaturationKey) ?? 0.78).clamp(0.25, 1.0).toDouble();
    _accentValue =
        (prefs.getDouble(_accentValueKey) ?? 1.0).clamp(0.62, 1.0).toDouble();
    _glassStrength =
        (prefs.getDouble(_glassStrengthKey) ?? 1.0).clamp(0.62, 1.35).toDouble();
    _backgroundBlur =
        (prefs.getDouble(_backgroundBlurKey) ?? 0).clamp(0, 18).toDouble();

    _customBackgroundPath = prefs.getString(_customBackgroundPathKey);
    _customBackgroundBytes = await LocalImageStore.read(_customBackgroundPath);
    if (_backgroundMode == PyreBackgroundMode.custom &&
        !hasCustomBackground) {
      _backgroundMode = PyreBackgroundMode.dynamic;
      await prefs.setString(_backgroundKey, _backgroundMode.name);
    }

    notifyListeners();
  }

  Future<void> setBackgroundMode(PyreBackgroundMode mode) async {
    if (mode == PyreBackgroundMode.custom && !hasCustomBackground) return;
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

  Future<void> setCustomBackground(Uint8List bytes) async {
    final oldPath = _customBackgroundPath;
    final path = await LocalImageStore.write(
      name: 'custom_background.jpg',
      bytes: bytes,
    );
    if (path == null) {
      throw StateError('Custom backgrounds are not supported on this platform.');
    }

    _customBackgroundPath = path;
    _customBackgroundBytes = Uint8List.fromList(bytes);
    _backgroundMode = PyreBackgroundMode.custom;
    notifyListeners();

    final prefs = await _preferences();
    await prefs.setString(_customBackgroundPathKey, path);
    await prefs.setString(_backgroundKey, _backgroundMode.name);

    if (oldPath != null && oldPath != path) {
      await LocalImageStore.delete(oldPath);
    }
  }

  Future<void> clearCustomBackground() async {
    final oldPath = _customBackgroundPath;
    _customBackgroundPath = null;
    _customBackgroundBytes = null;
    if (_backgroundMode == PyreBackgroundMode.custom) {
      _backgroundMode = PyreBackgroundMode.dynamic;
    }
    notifyListeners();

    final prefs = await _preferences();
    await prefs.remove(_customBackgroundPathKey);
    await prefs.setString(_backgroundKey, _backgroundMode.name);
    await LocalImageStore.delete(oldPath);
  }

  Future<void> setAccentHue(double value) async {
    final clamped = value.clamp(0, 360).toDouble();
    if ((_accentHue - clamped).abs() < 0.05) return;
    _accentHue = clamped;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.setDouble(_accentHueKey, clamped);
  }

  Future<void> setAccentSaturation(double value) async {
    final clamped = value.clamp(0.25, 1.0).toDouble();
    if ((_accentSaturation - clamped).abs() < 0.001) return;
    _accentSaturation = clamped;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.setDouble(_accentSaturationKey, clamped);
  }

  Future<void> setAccentValue(double value) async {
    final clamped = value.clamp(0.62, 1.0).toDouble();
    if ((_accentValue - clamped).abs() < 0.001) return;
    _accentValue = clamped;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.setDouble(_accentValueKey, clamped);
  }

  Future<void> setGlassStrength(double value) async {
    final clamped = value.clamp(0.62, 1.35).toDouble();
    if ((_glassStrength - clamped).abs() < 0.001) return;
    _glassStrength = clamped;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.setDouble(_glassStrengthKey, clamped);
  }

  Future<void> setBackgroundBlur(double value) async {
    final clamped = value.clamp(0, 18).toDouble();
    if ((_backgroundBlur - clamped).abs() < 0.001) return;
    _backgroundBlur = clamped;
    notifyListeners();
    final prefs = await _preferences();
    await prefs.setDouble(_backgroundBlurKey, clamped);
  }

  Future<void> reset() async {
    final oldPath = _customBackgroundPath;
    _backgroundMode = PyreBackgroundMode.dynamic;
    _backgroundVisibility = 1.0;
    _customBackgroundPath = null;
    _customBackgroundBytes = null;
    _accentHue = 24;
    _accentSaturation = 0.78;
    _accentValue = 1.0;
    _glassStrength = 1.0;
    _backgroundBlur = 0;
    notifyListeners();

    final prefs = await _preferences();
    await prefs.remove(_backgroundKey);
    await prefs.remove(_visibilityKey);
    await prefs.remove(_customBackgroundPathKey);
    await prefs.remove(_accentHueKey);
    await prefs.remove(_accentSaturationKey);
    await prefs.remove(_accentValueKey);
    await prefs.remove(_glassStrengthKey);
    await prefs.remove(_backgroundBlurKey);
    await LocalImageStore.delete(oldPath);
  }
}
