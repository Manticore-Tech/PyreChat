import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/client_identity.dart';

class PyreApiException implements Exception {
  PyreApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Chat send errors may originate from a remote service. Do not display raw
/// server error strings in the conversation UI: they can expose internal
/// details and often provide no actionable guidance to the sender.
extension ChatSendFailureCopy on PyreApiException {
  String get safeChatSendMessage => switch (statusCode) {
        400 => 'Message was not accepted. Check it and try again.',
        401 => 'Your session expired. Sign in again.',
        403 => 'You cannot send messages in this conversation.',
        404 => 'This conversation is no longer available.',
        409 when message ==
            'Private messaging is still setting up. Try again in a moment.' =>
          message,
        409 => 'Conversation is still syncing. Try again shortly.',
        429 => 'Too many messages. Try again shortly.',
        500 || 502 || 503 || 504 =>
          'Service temporarily unavailable. Try again shortly.',
        _ => 'Message could not be sent. Try again.',
      };
}

/// Loading a conversation must not expose server-generated error strings to
/// the user. Convert both transport failures and HTTP errors to trusted copy.
extension ChatLoadFailureCopy on PyreApiException {
  String get safeChatLoadMessage => switch (statusCode) {
        null => 'Could not connect. Check your internet connection and try again.',
        401 => 'Your session expired. Sign in again.',
        403 => 'You no longer have access to this conversation.',
        404 => 'This conversation is no longer available.',
        429 => 'Too many requests. Try again shortly.',
        500 || 502 || 503 || 504 =>
          'Service temporarily unavailable. Try again shortly.',
        _ => 'Could not load messages. Try again.',
      };
}

/// Signed-in-device failures can carry backend diagnostics. Never surface
/// the raw response in account-security UI or accessibility announcements.
extension SessionFailureCopy on PyreApiException {
  String get safeSessionMessage => switch (statusCode) {
        null => 'Could not connect. Check your internet connection and try again.',
        401 => 'Your session expired. Sign in again.',
        403 => 'You cannot manage these signed-in devices.',
        404 => 'That session is no longer available. Refresh and try again.',
        429 => 'Too many requests. Try again shortly.',
        500 || 502 || 503 || 504 =>
          'Service temporarily unavailable. Try again shortly.',
        _ => 'Could not update signed-in devices. Try again.',
      };
}

class PyreApi {
  PyreApi({String? origin}) : origin = _normalizeOrigin(origin ?? _configuredOrigin);

  static const _configuredOrigin = String.fromEnvironment(
    'PYRE_API_ORIGIN',
    defaultValue: 'https://pyre.social',
  );
  static const _requestTimeout = Duration(seconds: 20);

  static String _normalizeOrigin(String raw) {
    final value = raw.trim();
    if (value.isEmpty) throw ArgumentError.value(raw, 'origin', 'must not be empty');
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  final String origin;

  Map<String, String> get _clientHeaders => {
        'Content-Type': 'application/json',
        'X-Pyre-Client': pyreClientLabel(),
      };

  Future<http.Response> _request(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw PyreApiException('Request timed out');
    } on http.ClientException {
      throw PyreApiException('Could not reach Pyre Social');
    }
  }

  Future<({PyreUser user, String token})> login({
    required String username,
    required String password,
  }) async {
    final res = await _request(
      http.post(
        Uri.parse('$origin/api/auth/login'),
        headers: _clientHeaders,
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

  Future<void> deleteAccount({
    required String token,
    required String password,
  }) async {
    final res = await _request(
      http.delete(
        Uri.parse('$origin/api/me'),
        headers: _authHeaders(token),
        body: jsonEncode({'password': password}),
      ),
    );
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw PyreApiException(
        body['error'] as String? ?? 'Could not delete account',
        res.statusCode,
      );
    }
  }

  Map<String, String> _authHeaders(String token) => {
        ..._clientHeaders,
        'Authorization': 'Bearer $token',
      };

  Future<({PyreUser user, String token, String? recoveryKey})> signup({
    required String username,
    required String password,
    required String displayName,
    required String birthday,
    required bool acceptedTerms,
    required String termsVersion,
  }) async {
    final res = await _request(
      http.post(
        Uri.parse('$origin/api/auth/signup'),
        headers: _clientHeaders,
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
          'birthday': birthday,
          'acceptedTerms': acceptedTerms,
          'termsVersion': termsVersion,
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
