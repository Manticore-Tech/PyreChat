import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionPersistenceException implements Exception {
  const SessionPersistenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionStore {
  SessionStore({
    SecureTokenStore? secureTokenStore,
    bool? requireSecurePersistence,
  })  : _secureTokenStore = secureTokenStore ?? const PlatformSecureTokenStore(),
        _requireSecurePersistence =
            requireSecurePersistence ?? _isProductionMobileTarget;

  static const _tokenKey = 'pyre_token';
  static const _userKey = 'pyre_user';

  final SecureTokenStore _secureTokenStore;
  final bool _requireSecurePersistence;

  static bool get _isProductionMobileTarget =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);

    final secureStorageSupported = await _secureTokenStore.isSupported;
    if (secureStorageSupported) {
      final secureToken = await _secureTokenStore.read();
      if (secureToken != null && secureToken.isNotEmpty) {
        // Remove any plaintext copy left behind by an older build.
        if (legacyToken != null) await prefs.remove(_tokenKey);
        return secureToken;
      }

      if (legacyToken != null && legacyToken.isNotEmpty) {
        // Migrate an old plaintext session only if it can be persisted securely.
        if (await _secureTokenStore.write(legacyToken)) {
          await prefs.remove(_tokenKey);
          return legacyToken;
        }

        if (_requireSecurePersistence) {
          // Production mobile must not keep a bearer token usable only because
          // it survived in ordinary SharedPreferences.
          await prefs.remove(_tokenKey);
          return null;
        }

        return legacyToken;
      }
    }

    if (_requireSecurePersistence) {
      // Secure storage failure on Android/iOS is a signed-out state, not
      // permission to downgrade bearer-token persistence.
      if (legacyToken != null) await prefs.remove(_tokenKey);
      return null;
    }

    return legacyToken;
  }

  Future<PyreUser?> get user async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(_userKey);
        return null;
      }
      return PyreUser.fromJson(decoded);
    } catch (_) {
      // A stale/corrupt cache must never trap startup in a crash loop.
      await prefs.remove(_userKey);
      return null;
    }
  }

  Future<void> save({required String token, required PyreUser user}) async {
    final prefs = await SharedPreferences.getInstance();

    var tokenStoredSecurely = false;
    if (await _secureTokenStore.isSupported) {
      tokenStoredSecurely = await _secureTokenStore.write(token);
    }

    if (tokenStoredSecurely) {
      await prefs.remove(_tokenKey);
    } else if (_requireSecurePersistence) {
      await prefs.remove(_tokenKey);
      throw const SessionPersistenceException(
        'Secure session storage is unavailable. Sign in again after secure storage is restored.',
      );
    } else {
      // Explicit non-mobile development fallback only. Android/iOS default to
      // _requireSecurePersistence=true and never reach this branch.
      await prefs.setString(_tokenKey, token);
    }

    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
      }),
    );
  }

  Future<void> clear() async {
    await _secureTokenStore.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
