import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class SecureTokenStore {
  Future<bool> get isSupported;

  Future<String?> read();

  Future<bool> write(String token);

  Future<void> delete();
}

/// Mobile secure token storage.
///
/// Android keeps the encryption key inside Android Keystore. iOS stores the
/// bearer token in Keychain. Both hosts only return the token to Dart when
/// PyreChat needs it. SessionStore fails closed on production Android/iOS when
/// secure persistence is unavailable; plaintext fallback is non-mobile dev only.
class PlatformSecureTokenStore implements SecureTokenStore {
  const PlatformSecureTokenStore();

  static const MethodChannel _channel =
      MethodChannel('dev.pyrearms.pyrechat/secure_session');

  bool get _isSupportedMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> get isSupported async {
    if (!_isSupportedMobilePlatform) return false;
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
