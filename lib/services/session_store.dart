import 'dart:convert';

import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  SessionStore({SecureTokenStore? secureTokenStore})
      : _secureTokenStore = secureTokenStore ?? const PlatformSecureTokenStore();

  static const _tokenKey = 'pyre_token';
  static const _userKey = 'pyre_user';

  final SecureTokenStore _secureTokenStore;

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);

    if (await _secureTokenStore.isSupported) {
      final secureToken = await _secureTokenStore.read();
      if (secureToken != null && secureToken.isNotEmpty) {
        // Remove any plaintext copy left behind by an older build.
        if (legacyToken != null) await prefs.remove(_tokenKey);
        return secureToken;
      }

      if (legacyToken != null && legacyToken.isNotEmpty) {
        // Seamlessly migrate an existing signed-in Android session.
        if (await _secureTokenStore.write(legacyToken)) {
          await prefs.remove(_tokenKey);
        }
        return legacyToken;
      }
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
    } else {
      // Development fallback for platforms where secure storage is not wired
      // yet. Production mobile targets must use their platform secure store.
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
