// ignore_for_file: prefer_interpolation_to_compose_strings
// CPIM/SIP wire framing is deliberately assembled from exact literal sections.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pyrechat_flutter/services/secure_blob_store.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The only first-party RCS endpoint. No Flutter chat request is relayed
/// through the legacy PyreChat Worker.
class PyreRcsProtocol {
  static const origin = 'https://messages.pyre.social';
  static const socketOrigin = 'wss://messages.pyre.social';
  static const domain = 'messages.pyre.social';
  static final _handlePattern = RegExp(r'^[a-z][a-z0-9._-]{2,31}$');
  static final _messageIdPattern = RegExp(r'^[A-Za-z0-9_.@-]{12,140}$');

  static String handle(String value) {
    final clean = value.trim();
    if (!_handlePattern.hasMatch(clean)) {
      throw const PyreRcsException('Enter a valid lowercase RCS handle.');
    }
    return clean;
  }

  static String sip(String value) => 'sip:' + handle(value) + '@' + domain;

  /// Sender-facing UI uses account-mailbox delivery, not device FCM receipt.
  static String messageStatusLabel(String state) {
    switch (state) {
      case 'queued':
      case 'sent':
      case 'server-accepted': // Server acceptance does not prove delivery.
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'displayed':
        return 'Read';
      case 'failed':
        return 'Failed';
      default:
        return state;
    }
  }

  /// Accept the exact SIP address copied by the RCS inbox, or a bare handle.
  /// Foreign SIP domains, URI parameters, and malformed values are rejected.
  static String peerHandle(String value) {
    final input = value.trim();
    const prefix = 'sip:';
    const suffix = '@messages.pyre.social';
    if (input.startsWith(prefix)) {
      if (!input.endsWith(suffix)) {
        throw const PyreRcsException('Enter a Pyre Social RCS address.');
      }
      return handle(input.substring(prefix.length, input.length - suffix.length));
    }
    return handle(input);
  }

  static String base64url(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  static String messageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return 'm' + base64url(bytes);
  }

  static String newHandle() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return 'r' + bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  static String challengeText(String intent, String handle, String nonce) {
    if (intent != 'enroll' && intent != 'session') {
      throw const PyreRcsException('Invalid RCS identity intent.');
    }
    return 'pyresocial-rcs-v1\n' + intent + '\n' + sip(handle) + '\n' + nonce;
  }

  static String cpim({
    required String from,
    required String to,
    required String id,
    required String mime,
    required String content,
  }) {
    if (!_messageIdPattern.hasMatch(id)) {
      throw const PyreRcsException('Invalid RCS message ID.');
    }
    const allowed = {
      'text/plain; charset=utf-8',
      'message/imdn+xml',
      'application/im-iscomposing+xml',
      'application/vnd.pyresocial.mls+json',
    };
    if (!allowed.contains(mime) || content.isEmpty ||
        utf8.encode(content).length > 65536) {
      throw const PyreRcsException('Unsupported or oversized RCS message.');
    }
    return 'From: <' + sip(from) + '>\r\n'
        'To: <' + sip(to) + '>\r\n'
        'DateTime: ' + DateTime.now().toUtc().toIso8601String() + '\r\n'
        'NS: imdn <urn:ietf:params:imdn>\r\n'
        'imdn.Message-ID: ' + id + '\r\n\r\n'
        'Content-type: ' + mime + '\r\n\r\n' + content;
  }

  static PyreRcsMessage? parse(Map<String, dynamic> record, String localHandle) {
    final raw = record['cpim'];
    if (raw is! String) return null;
    final first = raw.indexOf('\r\n\r\n');
    if (first <= 0) return null;
    final second = raw.indexOf('\r\n\r\n', first + 4);
    if (second <= first) return null;
    final head = raw.substring(0, first);
    final mimeHeaders = raw.substring(first + 4, second);
    String? header(String content, String name) {
      final prefix = name.toLowerCase() + ':';
      for (final line in content.split('\r\n')) {
        if (line.toLowerCase().startsWith(prefix)) {
          return line.substring(prefix.length).trim();
        }
      }
      return null;
    }

    final fromUri = header(head, 'From');
    final toUri = header(head, 'To');
    final id = header(head, 'imdn.Message-ID');
    final mime = header(mimeHeaders, 'Content-type')?.toLowerCase();
    if (fromUri == null || toUri == null || id == null ||
        !_messageIdPattern.hasMatch(id) || mime == null) {
      return null;
    }
    String? peerHandle(String uri) {
      final match = RegExp(r'^<sip:([a-z][a-z0-9._-]{2,31})@messages\.pyre\.social>$')
          .firstMatch(uri);
      return match?.group(1);
    }
    final from = peerHandle(fromUri);
    final to = peerHandle(toUri);
    if (from == null || to == null ||
        (from != localHandle && to != localHandle)) {
      return null;
    }
    if (mime == 'message/imdn+xml' ||
        mime == 'application/im-iscomposing+xml') {
      return null; // Control events are not conversation bubbles.
    }
    if (mime != 'text/plain; charset=utf-8' &&
        mime != 'application/vnd.pyresocial.mls+json') {
      return null;
    }

    final seq = record['sequence'];
    return PyreRcsMessage(
      id: id,
      from: from,
      to: to,
      peer: from == localHandle ? to : from,
      incoming: from != localHandle,
      body: mime == 'text/plain; charset=utf-8'
          ? raw.substring(second + 4)
          : '[Encrypted payload: key exchange not linked on this device]',
      mime: mime,
      state: record['state']?.toString() ?? 'stored',
      createdAt: DateTime.tryParse(record['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sequence: seq is int ? seq : int.tryParse(seq?.toString() ?? '') ?? 0,
    );
  }

  static String receiptXml(String id, bool displayed) {
    if (!_messageIdPattern.hasMatch(id)) throw const PyreRcsException('Invalid receipt ID.');
    final state = displayed
        ? '<display-notification><status><displayed/></status></display-notification>'
        : '<delivery-notification><status><delivered/></status></delivery-notification>';
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<imdn xmlns="urn:ietf:params:xml:ns:imdn">'
        '<message-id>' + id + '</message-id>'
        '<datetime>' + DateTime.now().toUtc().toIso8601String() + '</datetime>'
        + state + '</imdn>';
  }

  static String composingXml(bool active) =>
      '<isComposing xmlns="urn:ietf:params:xml:ns:im-iscomposing">'
      '<state>' + (active ? 'active' : 'idle') + '</state></isComposing>';

  /// RFC 7118 SIP registration frame sent after the ticket-authenticated WSS
  /// upgrade. Ticket authenticates the device; SIP REGISTER declares the AoR.
  static String register(String handle) {
    final aor = sip(handle);
    final id = messageId();
    return 'REGISTER ' + aor + ' SIP/2.0\r\n'
        'Via: SIP/2.0/WSS ' + domain + ';branch=z9hG4bK' + id + '\r\n'
        'From: <' + aor + '>;tag=' + id + '\r\n'
        'To: <' + aor + '>\r\n'
        'Call-ID: ' + id + '@' + domain + '\r\n'
        'CSeq: 1 REGISTER\r\n'
        'Max-Forwards: 70\r\n'
        'Content-Length: 0\r\n\r\n';
  }
}

class PyreRcsException implements Exception {
  const PyreRcsException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class PyreRcsMessage {
  const PyreRcsMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.peer,
    required this.incoming,
    required this.body,
    required this.mime,
    required this.state,
    required this.createdAt,
    required this.sequence,
  });

  final String id;
  final String from;
  final String to;
  final String peer;
  final bool incoming;
  final String body;
  final String mime;
  final String state;
  final DateTime createdAt;
  final int sequence;
}

/// Direct RCS client for Android, iOS and the same Flutter web application.
///
/// The identity belongs to THIS device and is not silently conflated with a
/// preexisting Pyre Social username. Private signing material and bearer tokens
/// must be persisted in secure_blob_store, never SharedPreferences.
class PyreRcsClient extends ChangeNotifier {
  PyreRcsClient({
    required this.accountScope,
    SecureBlobStore? secrets,
    http.Client? httpClient,
    this.origin = PyreRcsProtocol.origin,
  })  : _secrets = secrets ?? const PlatformSecureBlobStore(),
        _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  final String accountScope;
  final SecureBlobStore _secrets;
  final http.Client _http;
  final bool _ownsHttp;
  final String origin;
  final Ed25519 _signer = Ed25519();
  Map<String, dynamic>? _identity;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _connecting = false;
  String? _typingPeer;
  Timer? _typingExpiry;
  String? _registeredFcmToken;
  bool _backgroundDeliveryReady = false;
  String _backgroundDeliveryNote = 'Waiting for device registration';
  Future<bool>? _backgroundRegistration;
  DateTime? _backgroundVerifiedAt;
  static const _notificationsChannel =
      MethodChannel('dev.pyrearms.pyrechat/notifications');
  static const _secureChannel =
      MethodChannel('dev.pyrearms.pyrechat/secure_session');
  static const _nativeGrantName = 'pyre_rcs_native_delivery_grant_v1';

  bool get connected => _channel != null;
  bool get backgroundDeliveryReady => _backgroundDeliveryReady;
  String get backgroundDeliveryNote => _backgroundDeliveryNote;

  /// Device-local RCS notification preview preference (default: on).
  /// Keeping it off still allows background wake and message synchronization.
  Future<bool> notificationPreviewsEnabled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await _notificationsChannel.invokeMethod<bool>(
          'getRcsMessagePreviews',
        ) ?? true;
  }

  Future<bool> setNotificationPreviewsEnabled(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await _notificationsChannel.invokeMethod<bool>(
          'setRcsMessagePreviews', {'enabled': enabled},
        ) ?? false;
  }

  void _setBackgroundDeliveryNote(String note) {
    if (_backgroundDeliveryNote == note) return;
    _backgroundDeliveryNote = note;
    if (!_closed) notifyListeners();
  }
  String? get typingPeer => _typingPeer;
  String? get handle => _identity?['handle'] as String?;
  String? get address => handle == null ? null : PyreRcsProtocol.sip(handle!);
  String get _secretSlot => 'pyre_rcs_identity_v1_' +
      PyreRcsProtocol.base64url(utf8.encode(accountScope));

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    final uri = Uri.parse(origin + path);
    final req = http.Request(method, uri);
    req.headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (bearer != null) req.headers['Authorization'] = 'Bearer ' + bearer;
    http.StreamedResponse response;
    try {
      response = await _http.send(req).timeout(const Duration(seconds: 16));
    } on TimeoutException {
      throw const PyreRcsException('RCS service timed out. Retry.');
    } catch (_) {
      throw const PyreRcsException('Cannot reach the independent RCS service.');
    }
    final raw = await response.stream.bytesToString();
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw PyreRcsException('RCS returned an invalid response.', response.statusCode);
    }
    if (response.statusCode >= 400) {
      final message = data['error']?.toString() ?? 'RCS request failed.';
      if (response.statusCode == 403 && message.toLowerCase().contains('enroll')) {
        throw const PyreRcsException(
          'RCS account enrollment is closed on the server. Your device identity is saved for retry.',
          403,
        );
      }
      throw PyreRcsException(message, response.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> _loadIdentity() async {
    if (_identity != null) return _identity!;
    if (!await _secrets.isSupported) {
      throw const PyreRcsException('Secure key storage is unavailable on this device.');
    }
    final raw = await _secrets.read(_secretSlot);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded['handle'] is String &&
            decoded['seed'] is String &&
            decoded['publicKey'] is String &&
            PyreRcsProtocol.handle(decoded['handle'] as String) ==
                decoded['handle']) {
          final seed = base64Url.decode(base64Url.normalize(decoded['seed'] as String));
          final pub = base64Url.decode(base64Url.normalize(decoded['publicKey'] as String));
          if (seed.length == 32 && pub.length == 32) {
            _identity = decoded;
            return decoded;
          }
        }
      } catch (_) {
        // A malformed secure record must not silently generate a new identity.
      }
      throw const PyreRcsException(
        'This device RCS identity cannot be recovered. Existing messages remain on the server.',
      );
    }
    final pair = await _signer.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final pub = await pair.extractPublicKey();
    final record = <String, dynamic>{
      'handle': PyreRcsProtocol.newHandle(),
      'seed': PyreRcsProtocol.base64url(seed),
      'publicKey': PyreRcsProtocol.base64url(pub.bytes),
      'enrolled': false,
    };
    if (!await _secrets.write(_secretSlot, jsonEncode(record))) {
      throw const PyreRcsException('Cannot securely save RCS signing keys.');
    }
    _identity = record;
    return record;
  }

  Future<void> _save(Map<String, dynamic> record) async {
    if (!await _secrets.write(_secretSlot, jsonEncode(record))) {
      throw const PyreRcsException('Cannot securely persist RCS session.');
    }
    _identity = record;
  }

  Future<void> ready() async {
    if (_closed) throw const PyreRcsException('RCS client closed.');
    final record = await _loadIdentity();
    final expires = DateTime.tryParse(record['expiresAt']?.toString() ?? '');
    if (record['token'] is String &&
        (record['token'] as String).isNotEmpty &&
        expires != null &&
        expires.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 2)))) {
      return;
    }
    final handle = PyreRcsProtocol.handle(record['handle'] as String);
    final enrolling = record['enrolled'] != true;
    final intent = enrolling ? 'enroll' : 'session';
    final challenge = await _request(
      'POST', '/v1/identity/challenge',
      body: {'handle': handle, 'intent': intent},
    );
    final nonce = challenge['nonce']?.toString();
    if (nonce == null || nonce.isEmpty) {
      throw const PyreRcsException('RCS challenge missing.');
    }
    final seed = base64Url.decode(base64Url.normalize(record['seed'] as String));
    final keyPair = await _signer.newKeyPairFromSeed(seed);
    final signature = await _signer.sign(
      utf8.encode(PyreRcsProtocol.challengeText(intent, handle, nonce)),
      keyPair: keyPair,
    );
    final response = await _request(
      'POST', enrolling ? '/v1/identity/enroll' : '/v1/identity/session',
      body: {
        'handle': handle,
        'nonce': nonce,
        'signature': PyreRcsProtocol.base64url(signature.bytes),
        if (enrolling) 'publicKey': record['publicKey'],
      },
    );
    final token = response['token']?.toString();
    final expiration = DateTime.tryParse(response['expiresAt']?.toString() ?? '');
    if (token == null || !token.startsWith(handle + '.') || expiration == null) {
      throw const PyreRcsException('RCS session response is invalid.');
    }
    await _save({
      ...record,
      'enrolled': true,
      'token': token,
      'expiresAt': expiration.toUtc().toIso8601String(),
    });
  }

  /// Registers an Android FCM token against this RCS identity and stores
  /// only a delivery-scoped grant using AndroidKeyStore-backed native storage.
  /// This is a best-effort platform feature; normal RCS must work without it.
  /// Avoid parallel registrations: each call rotates the device-only grant.
  /// Without single-flight, an older response can overwrite the newer grant
  /// in AndroidKeyStore, invalidating all background acknowledgements.
  Future<bool> registerAndroidBackgroundDelivery() {
    if (_closed || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future.value(false);
    }
    final pending = _backgroundRegistration;
    if (pending != null) return pending;
    final work = _registerAndroidBackgroundDelivery();
    _backgroundRegistration = work;
    return work.whenComplete(() => _backgroundRegistration = null);
  }

  /// The RCS account and message transport are never dependent on FCM.
  /// Firebase token creation can be slow on first launch; the inbox retries
  /// this registration while the app is foregrounded.
  Future<bool> _registerAndroidBackgroundDelivery() async {
    _setBackgroundDeliveryNote('Connecting notifications');
    try {
      final fcmToken = (await _notificationsChannel.invokeMethod<String>(
        'getPushToken',
      ).timeout(const Duration(seconds: 16)))?.trim();
      if (fcmToken == null || fcmToken.isEmpty) {
        _setBackgroundDeliveryNote('Waiting for Firebase device token');
        return false;
      }
      final bearer = await _token();
      final identity = await _loadIdentity();
      var deviceId = identity['pushDeviceId']?.toString() ?? '';
      if (!RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(deviceId)) {
        deviceId = 'd' + PyreRcsProtocol.messageId();
        await _save({...identity, 'pushDeviceId': deviceId});
      }

      if (_backgroundDeliveryReady && _registeredFcmToken == fcmToken) {
        final verifiedAt = _backgroundVerifiedAt;
        if (verifiedAt != null &&
            DateTime.now().difference(verifiedAt) < const Duration(minutes: 2)) {
          _setBackgroundDeliveryNote('Device registered for notifications');
          return true;
        }
        try {
          final registered = await _request(
            'GET', '/v1/rcs/push/status?deviceId=$deviceId', bearer: bearer,
          );
          if (registered['registered'] == true) {
            _backgroundVerifiedAt = DateTime.now();
            _setBackgroundDeliveryNote('Device registered for notifications');
            return true;
          }
        } catch (_) {
          // Server may have removed an invalid token; re-register safely.
        }
      }

      final response = await _request('POST', '/v1/rcs/push/register',
        bearer: bearer,
        body: <String, dynamic>{
          'deviceId': deviceId,
          'fcmToken': fcmToken,
          'platform': 'android',
        },
      );
      final deliveryKey = response['deliveryKey']?.toString() ?? '';
      final expiry = DateTime.tryParse(response['expiresAt']?.toString() ?? '');
      if (deliveryKey.length < 40 || expiry == null ||
          expiry.isBefore(DateTime.now().toUtc())) {
        throw const PyreRcsException('RCS push device proof is invalid.');
      }
      final stored = await _secureChannel.invokeMethod<bool>(
        'writeSecret',
        <String, String>{
          'name': _nativeGrantName,
          'value': jsonEncode(<String, Object>{
            'handle': handle!,
            'deviceId': deviceId,
            'deliveryKey': deliveryKey,
            'expiresAtMs': expiry.millisecondsSinceEpoch,
          }),
        },
      );
      if (stored != true) {
        _backgroundDeliveryReady = false;
        _setBackgroundDeliveryNote('Secure device storage unavailable');
        return false;
      }
      if (_closed) return false;
      _registeredFcmToken = fcmToken;
      _backgroundVerifiedAt = DateTime.now();
      _backgroundDeliveryReady = true;
      _setBackgroundDeliveryNote('Device registered for notifications');
      return true;
    } on MissingPluginException {
      _setBackgroundDeliveryNote('Android Firebase service unavailable');
    } on PlatformException {
      _setBackgroundDeliveryNote('Device notifications unavailable');
    } on TimeoutException {
      _setBackgroundDeliveryNote('Waiting for Firebase device token');
    } on PyreRcsException {
      _setBackgroundDeliveryNote('Push registration failed; will retry');
    } catch (_) {
      _setBackgroundDeliveryNote('Push registration unavailable; will retry');
    }
    return false;
  }

  /// Account-authenticated push diagnostics, never the FCM token or device
  /// grant. This does not change the state of any RCS message.
  Future<Map<String, dynamic>?> backgroundDeliveryHealth() async {
    if (_closed || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final identity = await _loadIdentity();
      final deviceId = identity['pushDeviceId']?.toString();
      if (deviceId == null || deviceId.isEmpty) {
        return <String, dynamic>{
          'registered': false,
          'note': _backgroundDeliveryNote,
        };
      }
      final status = await _request(
        'GET', '/v1/rcs/push/status?deviceId=$deviceId',
        bearer: await _token(),
      );
      if (status['registered'] != true) {
        _backgroundDeliveryReady = false;
        _setBackgroundDeliveryNote('No active device registration');
      } else {
        _backgroundVerifiedAt = DateTime.now();
      }
      return status;
    } catch (_) {
      return <String, dynamic>{
        'registered': _backgroundDeliveryReady,
        'note': 'Unable to check server push status',
      };
    }
  }

  Future<String> _token() async {
    await ready();
    final value = _identity?['token'];
    if (value is! String || value.isEmpty) {
      throw const PyreRcsException('RCS account has no session.');
    }
    return value;
  }

  Future<List<PyreRcsMessage>> history({int maxMessages = 1000}) async {
    final token = await _token();
    final items = <PyreRcsMessage>[];
    var after = 0;
    while (items.length < maxMessages) {
      final json = await _request('GET',
          '/v1/rcs/messages?after=' + after.toString() + '&limit=100',
          bearer: token);
      final page = json['messages'];
      if (page is! List) throw const PyreRcsException('RCS history is malformed.');
      for (final item in page) {
        if (item is Map<String, dynamic>) {
          final parsed = PyreRcsProtocol.parse(item, handle!);
          if (parsed != null) items.add(parsed);
        }
      }
      final next = json['nextCursor'];
      if (next == null) break;
      final value = next is int ? next : int.tryParse(next.toString());
      if (value == null || value <= after) {
        throw const PyreRcsException('RCS history cursor is invalid.');
      }
      after = value;
    }
    return items;
  }

  Future<Map<String, dynamic>> send(
    String peer,
    String content, {
    String mime = 'text/plain; charset=utf-8',
    String? messageId,
  }) async {
    final from = handle ?? (await _loadIdentity())['handle'] as String;
    final to = PyreRcsProtocol.handle(peer);
    if (to == from) throw const PyreRcsException('Cannot message your own address.');
    final cpim = PyreRcsProtocol.cpim(
      from: from, to: to,
      id: messageId ?? PyreRcsProtocol.messageId(),
      mime: mime, content: content,
    );
    final result = await _request('POST', '/v1/rcs/messages',
        body: {'cpim': cpim}, bearer: await _token());
    notifyListeners();
    return result;
  }

  Future<void> acknowledge(String peer, String originalId, {bool read = false}) async {
    final from = handle;
    if (from == null) throw const PyreRcsException('RCS account not initialized.');
    await send(peer, PyreRcsProtocol.receiptXml(originalId, read),
        mime: 'message/imdn+xml');
  }

  Future<void> typing(String peer, {required bool active}) =>
      send(peer, PyreRcsProtocol.composingXml(active),
          mime: 'application/im-iscomposing+xml').then((_) {});

  Future<String> status(String originalId) async {
    final result = await _request('GET',
        '/v1/rcs/status?id=' + Uri.encodeQueryComponent(originalId),
        bearer: await _token());
    return result['state']?.toString() ?? 'unknown';
  }

  Future<void> connect() async {
    if (_closed || _connecting || _channel != null) return;
    _connecting = true;
    try {
      final ticket = await _request('POST', '/v1/rcs/socket-ticket',
          body: <String, dynamic>{}, bearer: await _token());
      final proof = ticket['ticket']?.toString();
      if (proof == null || proof.isEmpty) {
        throw const PyreRcsException('RCS socket ticket missing.');
      }
      final address = Uri.parse(PyreRcsProtocol.socketOrigin +
          '/v1/sip?handle=' + Uri.encodeQueryComponent(handle!) +
          '&ticket=' + Uri.encodeQueryComponent(proof));
      final socket = WebSocketChannel.connect(address, protocols: ['sip']);
      _channel = socket;
      _subscription = socket.stream.listen(
        (event) {
          if (event is String && event.startsWith('MESSAGE ')) {
            _handleSipPush(event);
          }
        },
        onError: (Object _) => _scheduleReconnect(socket),
        onDone: () => _scheduleReconnect(socket),
        cancelOnError: true,
      );
      await socket.ready.timeout(const Duration(seconds: 10));
      socket.sink.add(PyreRcsProtocol.register(handle!));
      notifyListeners();
    } catch (_) {
      _scheduleReconnect(_channel);
    } finally {
      _connecting = false;
    }
  }

  void _handleSipPush(String raw) {
    final from = RegExp(
      r'(?:^|\r\n)From: <sip:([a-z][a-z0-9._-]{2,31})@messages\.pyre\.social>(?:;tag=[A-Za-z0-9._~-]+)?\r\n',
    ).firstMatch(raw)?.group(1);
    if (raw.contains('Content-type: application/im-iscomposing+xml') &&
        from != null) {
      final active = raw.contains('<state>active</state>');
      final idle = raw.contains('<state>idle</state>');
      if (!active && !idle) return;
      _typingExpiry?.cancel();
      _typingPeer = active ? from : null;
      if (active) {
        _typingExpiry = Timer(const Duration(seconds: 5), () {
          _typingPeer = null;
          if (!_closed) notifyListeners();
        });
      }
    } else if (from != null && from == _typingPeer) {
      _typingPeer = null;
      _typingExpiry?.cancel();
    }
    if (!_closed) notifyListeners();
  }

  void _scheduleReconnect(WebSocketChannel? previous) {
    if (_closed || (previous != null && !identical(previous, _channel))) return;
    _channel = null;
    _typingPeer = null;
    _typingExpiry?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 6), () {
      if (!_closed) unawaited(connect());
    });
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _reconnectTimer?.cancel();
    _typingExpiry?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    if (_ownsHttp) _http.close();
    super.dispose();
  }
}
