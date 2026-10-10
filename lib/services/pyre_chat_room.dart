import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef PyreChatRoomEventHandler = void Function(Map<String, dynamic> event);
typedef PyreChatRoomStatusHandler = void Function(PyreChatRoomStatus status);

enum PyreChatRoomStatus { disconnected, connecting, connected, reconnecting }

/// Per-conversation realtime transport.
///
/// The account-wide [PyreHub] remains responsible for inbox/account activity and
/// notifications. A live chat thread connects directly to the conversation
/// Durable Object so incoming messages can be rendered immediately instead of
/// waiting for an account-hub hint followed by an HTTP reload.
class PyreChatRoom {
  PyreChatRoom({
    required this.chatId,
    SessionStore? session,
    PyreApi? api,
  })  : _session = session ?? SessionStore(),
        _api = api ?? PyreApi();

  final String chatId;
  final SessionStore _session;
  final PyreApi _api;
  final _handlers = <PyreChatRoomEventHandler>[];
  final _statusHandlers = <PyreChatRoomStatusHandler>[];
  final _random = Random();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnect;
  bool _intentionalDisconnect = true;
  bool _connecting = false;
  bool _connected = false;
  int _reconnectAttempt = 0;
  PyreChatRoomStatus _status = PyreChatRoomStatus.disconnected;

  PyreChatRoomStatus get status => _status;

  void addListener(PyreChatRoomEventHandler handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  void removeListener(PyreChatRoomEventHandler handler) {
    _handlers.remove(handler);
  }

  void addStatusListener(PyreChatRoomStatusHandler handler) {
    if (!_statusHandlers.contains(handler)) _statusHandlers.add(handler);
  }

  void removeStatusListener(PyreChatRoomStatusHandler handler) {
    _statusHandlers.remove(handler);
  }

  void _setStatus(PyreChatRoomStatus value) {
    if (_status == value) return;
    _status = value;
    for (final handler
        in List<PyreChatRoomStatusHandler>.from(_statusHandlers)) {
      handler(value);
    }
  }

  Future<void> connect() async {
    _intentionalDisconnect = false;
    if (_connected || _connecting) return;
    await _open();
  }

  Future<void> reconnect() async {
    _intentionalDisconnect = false;
    _reconnect?.cancel();
    _reconnect = null;
    _reconnectAttempt = 0;
    await _closeTransport();
    await _open();
  }

  Future<void> _open() async {
    if (_intentionalDisconnect || _connecting) return;
    _connecting = true;
    _setStatus(
      _reconnectAttempt > 0
          ? PyreChatRoomStatus.reconnecting
          : PyreChatRoomStatus.connecting,
    );
    _reconnect?.cancel();
    _reconnect = null;

    await _closeTransport();

    try {
      final token = await _session.token;
      if (_intentionalDisconnect ||
          (!kIsWeb && (token == null || token.isEmpty))) {
        _setStatus(PyreChatRoomStatus.disconnected);
        return;
      }

      final encodedChatId = Uri.encodeComponent(chatId);
      final uri = Uri.parse(
        '${_api.origin.replaceFirst('https:', 'wss:').replaceFirst('http:', 'ws:')}/api/ws/chat/$encodedChatId',
      );

      final WebSocketChannel channel = kIsWeb
          ? WebSocketChannel.connect(uri)
          : IOWebSocketChannel.connect(
              uri,
              headers: {'Authorization': 'Bearer ${token!}'},
            );

      _channel = channel;
      _sub = channel.stream.listen(
        _handleRawEvent,
        onDone: _handleTransportLoss,
        onError: (Object error, StackTrace stackTrace) {
          if (kDebugMode) {
            debugPrint(
              '[PyreRoom] websocket error: ${error.runtimeType}: $error',
            );
          }
          _handleTransportLoss();
        },
      );

      await channel.ready.timeout(const Duration(seconds: 10));
      if (_intentionalDisconnect) {
        await _closeTransport();
        _setStatus(PyreChatRoomStatus.disconnected);
        return;
      }

      _reconnectAttempt = 0;
      _connected = true;
      _setStatus(PyreChatRoomStatus.connected);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[PyreRoom] connect failed: ${error.runtimeType}: $error',
        );
      }
      await _closeTransport();
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _handleRawEvent(dynamic raw) {
    try {
      if (raw is! String) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      for (final handler
          in List<PyreChatRoomEventHandler>.from(_handlers)) {
        handler(decoded);
      }
    } catch (_) {
      // Malformed room activity is isolated from the live thread.
    }
  }

  void _handleTransportLoss() {
    _connected = false;
    if (!_intentionalDisconnect) {
      _setStatus(PyreChatRoomStatus.reconnecting);
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || (_reconnect?.isActive ?? false)) return;

    const seconds = [1, 2, 4, 8, 15, 30];
    final index = _reconnectAttempt.clamp(0, seconds.length - 1);
    final delay = Duration(
      seconds: seconds[index],
      milliseconds: _random.nextInt(500),
    );
    _reconnectAttempt++;
    _setStatus(PyreChatRoomStatus.reconnecting);
    _reconnect = Timer(delay, _open);
  }

  Future<void> _closeTransport() async {
    _connected = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Transport is already gone.
    }
    _channel = null;
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnect?.cancel();
    _reconnect = null;
    await _closeTransport();
    _setStatus(PyreChatRoomStatus.disconnected);
  }
}
