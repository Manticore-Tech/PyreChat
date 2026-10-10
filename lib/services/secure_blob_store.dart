import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureBlobStore {
  Future<bool> get isSupported;

  Future<String?> read(String name);

  Future<bool> write(String name, String value);

  Future<void> delete(String name);
}

/// Small secret/blob storage backed by platform secure storage.
///
/// Android uses the PyreChat Keystore AES-GCM host and iOS uses Keychain.
/// Browser storage uses flutter_secure_storage's WebCrypto-backed encrypted
/// same-origin storage. Browsers do not offer hardware-backed guarantees and
/// clearing site data removes the local MLS identity; this never falls back to
/// plaintext storage if WebCrypto/storage is unavailable.
class PlatformSecureBlobStore implements SecureBlobStore {
  const PlatformSecureBlobStore();

  static const MethodChannel _channel =
      MethodChannel('dev.pyrearms.pyrechat/secure_session');

  static final FlutterSecureStorage _browser = FlutterSecureStorage(
    webOptions: const WebOptions(
      dbName: 'PyreSocialEncryptedStorage',
      publicKey: 'PyreSocialWebCrypto',
    ),
  );
  static Future<bool>? _browserSupport;

  static Future<bool> _probeBrowserStorage() async {
    try {
      const key = 'pyre_social_secure_probe_v1';
      final proof = DateTime.now().microsecondsSinceEpoch.toString();
      await _browser.write(key: key, value: proof);
      final persisted = await _browser.read(key: key);
      await _browser.delete(key: key);
      return persisted == proof;
    } catch (_) {
      return false;
    }
  }

  bool get _isSupportedMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> get isSupported async {
    if (kIsWeb) {
      final supported = await (_browserSupport ??= _probeBrowserStorage());
      // A transient IndexedDB/WebCrypto error should not lock the browser
      // into "unsupported" until someone reloads the app.
      if (!supported) _browserSupport = null;
      return supported;
    }
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
  Future<String?> read(String name) async {
    if (name.trim().isEmpty || !await isSupported) return null;
    if (kIsWeb) {
      try {
        return await _browser.read(key: name);
      } catch (_) {
        return null;
      }
    }
    try {
      return await _channel.invokeMethod<String?>(
        'readSecret',
        <String, Object?>{'name': name},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> write(String name, String value) async {
    if (name.trim().isEmpty || !await isSupported) return false;
    if (kIsWeb) {
      try {
        await _browser.write(key: name, value: value);
        return await _browser.read(key: name) == value;
      } catch (_) {
        return false;
      }
    }
    try {
      return await _channel.invokeMethod<bool>(
            'writeSecret',
            <String, Object?>{'name': name, 'value': value},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> delete(String name) async {
    if (name.trim().isEmpty || !await isSupported) return;
    if (kIsWeb) {
      try {
        await _browser.delete(key: name);
      } catch (_) {
        // Browser storage may be unavailable in private mode.
      }
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'deleteSecret',
        <String, Object?>{'name': name},
      );
    } on MissingPluginException {
      // Target does not expose a secure blob backend.
    } on PlatformException {
      // Best-effort cleanup.
    }
  }
}
