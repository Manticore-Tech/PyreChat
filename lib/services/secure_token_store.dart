import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class SecureTokenStore {
  Future<bool> get isSupported;

  Future<String?> read();

  Future<bool> write(String token);

  Future<void> delete();
}

/// Android-backed secure token storage.
///
/// The Android host keeps the encryption key inside Android Keystore and only
/// returns the decrypted bearer token to the Dart process when PyreChat needs
/// it. Other platforms currently fall back to the existing development store.
class PlatformSecureTokenStore implements SecureTokenStore {
  const PlatformSecureTokenStore();

  static const MethodChannel _channel =
      MethodChannel('dev.pyrearms.pyrechat/secure_session');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> get isSupported async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> read() async {
    if (!await isSupported) return null;
    try {
      final value = await _channel.invokeMethod<String?>('readToken');
      return value?.trim().isEmpty == true ? null : value;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> write(String token) async {
    if (!await isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'writeToken',
            <String, Object?>{'token': token},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> delete() async {
    if (!await isSupported) return;
    try {
      await _channel.invokeMethod<void>('deleteToken');
    } on MissingPluginException {
      // The platform implementation is unavailable; nothing secure to clear.
    } on PlatformException {
      // Logout still clears the legacy local cache below.
    }
  }
}
