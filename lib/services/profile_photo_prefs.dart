import 'package:flutter/foundation.dart';
import 'package:pyrechat_flutter/services/local_image_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePhotoPrefs extends ChangeNotifier {
  ProfilePhotoPrefs({SharedPreferences? prefs}) : _prefs = prefs;

  static final ProfilePhotoPrefs instance = ProfilePhotoPrefs();

  SharedPreferences? _prefs;
  String? _userId;
  String? _path;
  Uint8List? _bytes;

  String? get userId => _userId;
  Uint8List? get bytes => _bytes;

  Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String _pathKey(String userId) => 'profile_photo_path_$userId';

  Future<void> loadFor(String userId) async {
    if (_userId == userId && _bytes != null) return;

    final prefs = await _preferences();
    final path = prefs.getString(_pathKey(userId));
    final bytes = await LocalImageStore.read(path);

    _userId = userId;
    _path = bytes == null ? null : path;
    _bytes = bytes;
    notifyListeners();

    if (path != null && bytes == null) {
      await prefs.remove(_pathKey(userId));
    }
  }

  Future<void> setFor(String userId, Uint8List bytes) async {
    final oldPath = _userId == userId ? _path : null;
    final safeId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path = await LocalImageStore.write(
      name: 'profile_$safeId.jpg',
      bytes: bytes,
    );
    if (path == null) {
      throw StateError('Profile photos are not supported on this platform.');
    }

    _userId = userId;
    _path = path;
    _bytes = Uint8List.fromList(bytes);
    notifyListeners();

    final prefs = await _preferences();
    await prefs.setString(_pathKey(userId), path);

    if (oldPath != null && oldPath != path) {
      await LocalImageStore.delete(oldPath);
    }
  }

  Future<void> clearFor(String userId) async {
    final oldPath = _userId == userId ? _path : null;
    if (_userId == userId) {
      _path = null;
      _bytes = null;
      notifyListeners();
    }

    final prefs = await _preferences();
    await prefs.remove(_pathKey(userId));
    await LocalImageStore.delete(oldPath);
  }
}
