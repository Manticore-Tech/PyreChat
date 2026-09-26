import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/models/snap_detail.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/session_events.dart';
import 'package:pyrechat_flutter/services/session_store.dart';

/// Authenticated API client — mirrors Android `PyreClient.kt`.
class PyreClient {
  PyreClient({SessionStore? session, PyreApi? api})
      : _session = session ?? SessionStore(),
        _api = api ?? PyreApi();

  final SessionStore _session;
  final PyreApi _api;
  static const _requestTimeout = Duration(seconds: 20);

  Future<String> _token() async {
    final token = await _session.token;
    if (token == null || token.isEmpty) {
      SessionEvents.instance.invalidate();
      throw PyreApiException('Not signed in', 401);
    }
    return token;
  }

  Map<String, String> _headers(String token, {String? contentType}) => {
        if (contentType != null) 'Content-Type': contentType,
        'Authorization': 'Bearer $token',
      };

  Future<http.Response> _request(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw PyreApiException('Request timed out');
    } on http.ClientException {
      throw PyreApiException('Could not reach PyreChat');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to the stable client-facing error below.
    }
    throw PyreApiException(
      'PyreChat returned an invalid response',
      res.statusCode >= 400 ? res.statusCode : null,
    );
  }

  Never _fail(http.Response res) {
    Map<String, dynamic> body = const {};
    try {
      body = _decode(res);
    } on PyreApiException {
      // Preserve the HTTP status and use the generic message below.
    }

    final message = body['error'] as String? ?? 'Request failed';
    if (res.statusCode == 401) {
      SessionEvents.instance.invalidate();
    }
    throw PyreApiException(message, res.statusCode);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final token = await _token();
    final res = await _request(
      http.get(
        Uri.parse('${_api.origin}$path'),
        headers: _headers(token, contentType: 'application/json'),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(
    String path, [
    Map<String, dynamic>? json,
  ]) async {
    final token = await _token();
    final res = await _request(
      http.post(
        Uri.parse('${_api.origin}$path'),
        headers: _headers(token, contentType: 'application/json'),
        body: jsonEncode(json ?? {}),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    return _decode(res);
  }

  Future<PyreUser> me() async {
    final user = await _api.me(token: await _token());
    final token = await _token();
    await _session.save(token: token, user: user);
    return user;
  }

  Future<List<PyreFriend>> friends() async {
    final body = await _get('/api/friends');
    final arr = body['friends'] as List<dynamic>? ?? [];
    return arr
        .map((e) => PyreFriend.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PyreFriend>> searchUsers(String query) async {
    if (query.trim().isEmpty) return const [];
    final encoded = Uri.encodeQueryComponent(query.trim());
    final body = await _get('/api/users/search?q=$encoded');
    final arr = body['users'] as List<dynamic>? ?? [];
    return arr
        .map((e) => PyreFriend.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PyreFriend>> quickAdd() async {
    final body = await _get('/api/friends/quick-add');
    final arr = body['suggestions'] as List<dynamic>? ?? [];
    return arr
        .map((e) => PyreFriend.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<FriendAddsBundle> friendAdds() async {
    final body = await _get('/api/friends/adds');
    return FriendAddsBundle.fromJson(body);
  }

  Future<String> addFriend({String? username, String? userId}) async {
    final body = await _post('/api/friends/add', {
      if (username != null) 'username': username,
      if (userId != null) 'userId': userId,
    });
    return body['status'] as String? ?? 'ok';
  }

  Future<void> dismissFriend({
    required String userId,
    required String kind,
  }) async {
    await _post('/api/friends/dismiss', {
      'userId': userId,
      'kind': kind,
    });
  }

  Future<void> restoreFriend(String userId) async {
    await _post('/api/friends/restore', {'userId': userId});
  }

  Future<void> removeFriend(String userId) async {
    await _post('/api/friends/remove', {'userId': userId});
  }

  Future<List<ChatPreview>> chats() async {
    final body = await _get('/api/chats');
    final arr = body['chats'] as List<dynamic>? ?? [];
    final meId = (await _session.user)?.id;
    return arr
        .map((e) => ChatPreview.fromApi(e as Map<String, dynamic>, meId: meId))
        .toList(growable: false);
  }

  Future<bool> muteChat(String chatId, {required bool muted}) async {
    final body = await _post('/api/chats/$chatId/mute', {'muted': muted});
    return body['muted'] == true;
  }

  Future<void> clearChat(String chatId) async {
    await _post('/api/chats/$chatId/clear');
  }

  Future<List<ChatMessage>> messages(String chatId) async {
    final body = await _get('/api/chats/$chatId/messages');
    final arr = body['messages'] as List<dynamic>? ?? [];
    return arr
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<String> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final body = await _post('/api/chats/$chatId/messages', {
      'kind': 'text',
      'body': text,
    });
    return body['id'] as String;
  }

  Future<String> uploadMedia(Uint8List bytes, {String mime = 'image/jpeg'}) async {
    final token = await _token();
    final res = await _request(
      http.post(
        Uri.parse('${_api.origin}/api/media'),
        headers: _headers(token, contentType: mime),
        body: bytes,
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    final body = _decode(res);
    return body['key'] as String;
  }

  Future<String> sendSnap({
    required String mediaKey,
    required List<String> recipientIds,
    String kind = 'photo',
    String caption = '',
    String? conversationId,
  }) async {
    final body = await _post('/api/snaps', {
      'mediaKey': mediaKey,
      'kind': kind,
      'caption': caption,
      'recipientIds': recipientIds,
      if (conversationId != null) 'conversationId': conversationId,
    });
    return body['id'] as String;
  }

  Future<SnapDetail> getSnap(String snapId) async {
    final body = await _get('/api/snaps/$snapId');
    return SnapDetail.fromJson(body, _api.origin);
  }

  Future<void> markSnapViewed(String snapId) async {
    await _post('/api/snaps/$snapId/view');
  }

  Future<Uint8List> fetchMediaBytes(String mediaKey) async {
    final token = await _token();
    final encoded = Uri.encodeComponent(mediaKey);
    final res = await _request(
      http.get(
        Uri.parse('${_api.origin}/api/media/$encoded'),
        headers: _headers(token),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    return res.bodyBytes;
  }

  Future<Uint8List> fetchSnapMedia(SnapDetail snap) async {
    final token = await _token();
    final res = await _request(
      http.get(
        Uri.parse(snap.mediaUrl),
        headers: _headers(token),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    return res.bodyBytes;
  }
}
