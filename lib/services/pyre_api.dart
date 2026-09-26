import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pyrechat_flutter/models/user.dart';

class PyreApiException implements Exception {
  PyreApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PyreApi {
  PyreApi({String? origin}) : origin = _normalizeOrigin(origin ?? _configuredOrigin);

  static const _configuredOrigin = String.fromEnvironment(
    'PYRE_API_ORIGIN',
    defaultValue: 'https://chat.pyrearms.dev',
  );
  static const _requestTimeout = Duration(seconds: 20);

  static String _normalizeOrigin(String raw) {
    final value = raw.trim();
    if (value.isEmpty) throw ArgumentError.value(raw, 'origin', 'must not be empty');
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  final String origin;

  Future<http.Response> _request(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw PyreApiException('Request timed out');
    } on http.ClientException {
      throw PyreApiException('Could not reach PyreChat');
    }
  }

  Future<({PyreUser user, String token})> login({
    required String username,
    required String password,
  }) async {
    final res = await _request(
      http.post(
        Uri.parse('$origin/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw PyreApiException(
        body['error'] as String? ?? 'Could not log in',
        res.statusCode,
      );
    }
    return (
      user: PyreUser.fromJson(body['user'] as Map<String, dynamic>),
      token: body['token'] as String,
    );
  }

  Future<PyreUser> me({required String token}) async {
    final res = await _request(
      http.get(
        Uri.parse('$origin/api/me'),
        headers: _authHeaders(token),
      ),
    );
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw PyreApiException(
        body['error'] as String? ?? 'Could not load session',
        res.statusCode,
      );
    }
    return PyreUser.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<void> logout({required String token}) async {
    final res = await _request(
      http.post(
        Uri.parse('$origin/api/auth/logout'),
        headers: _authHeaders(token),
      ),
    );
    if (res.statusCode >= 400 && res.statusCode != 401) {
      final body = _decode(res);
      throw PyreApiException(
        body['error'] as String? ?? 'Could not log out',
        res.statusCode,
      );
    }
  }

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<({PyreUser user, String token, String? recoveryKey})> signup({
    required String username,
    required String password,
    required String displayName,
    required String birthday,
  }) async {
    final res = await _request(
      http.post(
        Uri.parse('$origin/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
          'birthday': birthday,
        }),
      ),
    );
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw PyreApiException(
        body['error'] as String? ?? 'Could not sign up',
        res.statusCode,
      );
    }
    return (
      user: PyreUser.fromJson(body['user'] as Map<String, dynamic>),
      token: body['token'] as String,
      recoveryKey: body['recoveryKey'] as String?,
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
