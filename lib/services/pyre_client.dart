import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/models/snap_detail.dart';
import 'package:pyrechat_flutter/models/session.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/message_transport.dart';
import 'package:pyrechat_flutter/services/session_events.dart';
import 'package:pyrechat_flutter/services/session_store.dart';

/// Authenticated API client — mirrors Android `PyreClient.kt`.
class PyreClient {
  PyreClient({SessionStore? session, PyreApi? api, PyreMessageTransport? messageTransport})
      : _session = session ?? SessionStore(),
        _api = api ?? PyreApi(),
        _injectedMessageTransport = messageTransport;

  final SessionStore _session;
  final PyreApi _api;
  final PyreMessageTransport? _injectedMessageTransport;
  late final PyreMessageTransport _messaging = _injectedMessageTransport ??
      LegacyPyreMessageTransport(get: _get, post: (path, payload) => _post(path, payload));
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

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> json,
  ) async {
    final token = await _token();
    final res = await _request(
      http.patch(
        Uri.parse('${_api.origin}$path'),
        headers: _headers(token, contentType: 'application/json'),
        body: jsonEncode(json),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    return _decode(res);
  }

  Future<void> blockUser(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw PyreApiException('User not found');
    }
    await _post('/api/block', {'userId': cleanUserId});
  }

  Future<void> unblockUser(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;
    await _post('/api/unblock', {'userId': cleanUserId});
  }

  Future<void> reportUser({
    required String userId,
    required String reason,
    String detail = '',
  }) async {
    await _post('/api/reports', {
      'targetKind': 'user',
      'targetUserId': userId.trim(),
      'reason': reason,
      'detail': detail.trim(),
    });
  }

  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String detail = '',
  }) async {
    await _post('/api/reports', {
      'targetKind': 'message',
      'targetId': messageId.trim(),
      'reason': reason,
      'detail': detail.trim(),
    });
  }

  Future<void> reportSnap({
    required String snapId,
    required String reason,
    String detail = '',
  }) async {
    await _post('/api/reports', {
      'targetKind': 'snap',
      'targetId': snapId.trim(),
      'reason': reason,
      'detail': detail.trim(),
    });
  }

  Future<PyreUser> me() async {
    final user = await _api.me(token: await _token());
    final token = await _token();
    await _session.save(token: token, user: user);
    return user;
  }

  Future<PyreUser> updateIdentity({
    required String username,
    required String displayName,
    String? currentPassword,
  }) async {
    final body = await _patch('/api/me', {
      'username': username.trim(),
      'displayName': displayName.trim(),
      if (currentPassword != null && currentPassword.isNotEmpty)
        'currentPassword': currentPassword,
    });
    final user = PyreUser.fromJson(body['user'] as Map<String, dynamic>);
    final token = await _token();
    await _session.save(token: token, user: user);
    return user;
  }

  Future<String> rotateRecoveryKey(String password) async {
    final body = await _post('/api/me/recovery-key', {
      'password': password,
    });
    final key = body['recoveryKey']?.toString().trim() ?? '';
    if (key.isEmpty) {
      throw PyreApiException('PyreChat did not return a recovery key');
    }
    return key;
  }

  Future<List<PyreSession>> sessions() async {
    final body = await _get('/api/me/sessions');
    final rows = body['sessions'] as List<dynamic>? ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(PyreSession.fromJson)
        .where((session) => session.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> bindCurrentSessionDevice({
    required String deviceId,
    required String label,
  }) async {
    await _post('/api/me/sessions/current/device', {
      'deviceId': deviceId.trim(),
      'label': label.trim(),
    });
  }

  Future<bool> revokeSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return false;
    final token = await _token();
    final res = await _request(
      http.delete(
        Uri.parse('${_api.origin}/api/me/sessions/${Uri.encodeComponent(id)}'),
        headers: _headers(token, contentType: 'application/json'),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    final body = _decode(res);
    return body['current'] == true;
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

  Future<List<ChatMessage>> messages(String chatId) => _messaging.messages(chatId);

  /// True once this conversation has an established MLS group. The backend
  /// refuses standard plaintext messages in that case even if the UI is stale.
  Future<bool> isChatEndToEndEncrypted(String chatId) => _messaging.isEncrypted(chatId);

  /// Acknowledges encrypted or standard messages only after they reach this
  /// signed-in client. Setting read also implies delivered on the server.
  Future<void> acknowledgeMessages({
    required String chatId,
    required List<String> messageIds,
    required bool read,
  }) => _messaging.acknowledge(chatId: chatId, messageIds: messageIds, read: read);

  Future<String> sendMessage({
    required String chatId,
    required String text,
    String? clientId,
  }) => _messaging.sendText(chatId: chatId, text: text, clientId: clientId);

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

  Future<PyreUser> uploadProfilePhoto(
    Uint8List bytes, {
    String mime = 'image/jpeg',
  }) async {
    final token = await _token();
    final res = await _request(
      http.put(
        Uri.parse('${_api.origin}/api/me/avatar'),
        headers: _headers(token, contentType: mime),
        body: bytes,
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    final body = _decode(res);
    final user = PyreUser.fromJson(body['user'] as Map<String, dynamic>);
    await _session.save(token: token, user: user);
    return user;
  }

  Future<PyreUser> removeProfilePhoto() async {
    final token = await _token();
    final res = await _request(
      http.delete(
        Uri.parse('${_api.origin}/api/me/avatar'),
        headers: _headers(token, contentType: 'application/json'),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
    final body = _decode(res);
    final user = PyreUser.fromJson(body['user'] as Map<String, dynamic>);
    await _session.save(token: token, user: user);
    return user;
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? appId,
  }) async {
    if (token.trim().isEmpty) return;
    await _post('/api/push/register', {
      'token': token.trim(),
      'platform': platform,
      if (appId != null && appId.trim().isNotEmpty) 'appId': appId.trim(),
    });
  }

  Future<void> unregisterPushToken(String token) async {
    if (token.trim().isEmpty) return;
    final auth = await _token();
    final res = await _request(
      http.delete(
        Uri.parse('${_api.origin}/api/push/register'),
        headers: _headers(auth, contentType: 'application/json'),
        body: jsonEncode({'token': token.trim()}),
      ),
    );
    if (res.statusCode >= 400) _fail(res);
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
  Future<({
    bool registered,
    int availableKeyPackages,
    String? signerPublicKey,
  })> e2eeDeviceStatus(String deviceId) async {
    final trimmed = deviceId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'must not be empty');
    }
    final encoded = Uri.encodeQueryComponent(trimmed);
    final body = await _get('/api/e2ee/device/status?deviceId=$encoded');
    return (
      registered: body['registered'] == true,
      availableKeyPackages: (body['available'] as num?)?.toInt() ?? 0,
      signerPublicKey: body['signerPublicKey'] as String?,
    );
  }

  Future<int> registerE2eeDevice({
    required String deviceId,
    required String signerPublicKey,
    required List<String> keyPackages,
  }) async {
    if (deviceId.trim().isEmpty || signerPublicKey.trim().isEmpty) {
      throw ArgumentError('MLS device identity must not be empty');
    }
    if (keyPackages.length > 16) {
      throw ArgumentError.value(
        keyPackages.length,
        'keyPackages',
        'must contain at most 16 packages',
      );
    }
    final body = await _post('/api/e2ee/device/register', {
      'deviceId': deviceId.trim(),
      'signerPublicKey': signerPublicKey.trim(),
      'keyPackages': keyPackages,
    });
    return (body['available'] as num?)?.toInt() ?? 0;
  }

  Future<({
    bool enabled,
    String? groupId,
    String? protocol,
    String? createdAt,
    String? welcome,
  })> e2eeChatState({
    required String chatId,
    required String deviceId,
  }) async {
    final encodedDevice = Uri.encodeQueryComponent(deviceId.trim());
    final body =
        await _get('/api/e2ee/chats/$chatId/state?deviceId=$encodedDevice');
    return (
      enabled: body['enabled'] == true,
      groupId: body['groupId'] as String?,
      protocol: body['protocol'] as String?,
      createdAt: body['createdAt'] as String?,
      welcome: body['welcome'] as String?,
    );
  }

  Future<({
    bool existing,
    String? groupId,
    String? attemptId,
    List<({String userId, String deviceId, String keyPackage})> members,
  })> e2eeBootstrapMaterial({
    required String chatId,
    required String deviceId,
  }) async {
    final body = await _post('/api/e2ee/chats/$chatId/bootstrap-material', {
      'deviceId': deviceId.trim(),
    });
    final rawMembers = body['members'] as List<dynamic>? ?? const [];
    final members = rawMembers.map((raw) {
      final map = raw as Map<String, dynamic>;
      return (
        userId: map['userId'] as String,
        deviceId: map['deviceId'] as String,
        keyPackage: map['keyPackage'] as String,
      );
    }).toList(growable: false);
    return (
      existing: body['existing'] == true,
      groupId: body['groupId'] as String?,
      attemptId: body['attemptId'] as String?,
      members: members,
    );
  }

  Future<({bool created, String groupId})> bootstrapE2eeChat({
    required String chatId,
    required String deviceId,
    required String attemptId,
    required String groupId,
    required String welcome,
  }) async {
    final body = await _post('/api/e2ee/chats/$chatId/bootstrap', {
      'deviceId': deviceId.trim(),
      'attemptId': attemptId,
      'groupId': groupId,
      'welcome': welcome,
    });
    return (
      created: body['created'] == true,
      groupId: body['groupId'] as String? ?? '',
    );
  }

  Future<void> consumeE2eeWelcome({
    required String chatId,
    required String deviceId,
  }) async {
    await _post('/api/e2ee/chats/$chatId/welcome/consume', {
      'deviceId': deviceId.trim(),
    });
  }

  Future<({bool allReady, bool legacyPlaintextPurged})> markE2eeLegacyReady({
    required String chatId,
    required String deviceId,
  }) async {
    final body = await _post('/api/e2ee/chats/$chatId/legacy-ready', {
      'deviceId': deviceId.trim(),
    });
    return (
      allReady: body['allReady'] == true,
      legacyPlaintextPurged: body['legacyPlaintextPurged'] == true,
    );
  }

  Future<String> sendMlsMessage({
    required String chatId,
    required String ciphertext,
    required String clientId,
  }) => _messaging.sendEncrypted(chatId: chatId, ciphertext: ciphertext, clientId: clientId);
}
