import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef HubEventHandler = void Function(Map<String, dynamic> event);
typedef HubStatusHandler = void Function(PyreHubStatus status);

enum PyreHubStatus { disconnected, connecting, connected, reconnecting }

/// Live authenticated event hub used by chats, snaps, and account activity.
///
/// Reconnects are bounded and jittered so a temporary outage does not turn every
/// client into a synchronized reconnect loop. An explicit [disconnect] never
/// schedules a new connection.
class PyreHub {
  PyreHub({SessionStore? session, PyreApi? api})
      : _session = session ?? SessionStore(),
        _api = api ?? PyreApi();

  final SessionStore _session;
  final PyreApi _api;
  final _handlers = <HubEventHandler>[];
  final _statusHandlers = <HubStatusHandler>[];
  final _random = Random();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _reconnect;
  bool _intentionalDisconnect = true;
  bool _connecting = false;
  bool _connected = false;
  int _reconnectAttempt = 0;
  PyreHubStatus _status = PyreHubStatus.disconnected;

  PyreHubStatus get status => _status;

  void addListener(HubEventHandler handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  void removeListener(HubEventHandler handler) => _handlers.remove(handler);

  void addStatusListener(HubStatusHandler handler) {
    if (!_statusHandlers.contains(handler)) _statusHandlers.add(handler);
  }

  void removeStatusListener(HubStatusHandler handler) =>
      _statusHandlers.remove(handler);

  void _setStatus(PyreHubStatus value) {
    if (_status == value) return;
    _status = value;
    for (final handler in List<HubStatusHandler>.from(_statusHandlers)) {
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
          ? PyreHubStatus.reconnecting
          : PyreHubStatus.connecting,
    );
    _reconnect?.cancel();
    _reconnect = null;

    await _closeTransport();

    try {
      final token = await _session.token;
      if (_intentionalDisconnect || token == null || token.isEmpty) {
        _setStatus(PyreHubStatus.disconnected);
        return;
      }

      final uri = Uri.parse(
        '${_api.origin.replaceFirst('https:', 'wss:').replaceFirst('http:', 'ws:')}/api/ws/hub',
      );
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      _channel = channel;
      _sub = channel.stream.listen(
        _handleRawEvent,
        onDone: _handleTransportLoss,
        onError: (_) => _handleTransportLoss(),
      );

      await channel.ready.timeout(const Duration(seconds: 10));
      if (_intentionalDisconnect) {
        await _closeTransport();
        _setStatus(PyreHubStatus.disconnected);
        return;
      }

      _reconnectAttempt = 0;
      _connected = true;
      _setStatus(PyreHubStatus.connected);
      _startPing();
    } catch (_) {
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
      if (decoded['type'] == 'pong') _reconnectAttempt = 0;
      for (final handler in List<HubEventHandler>.from(_handlers)) {
        handler(decoded);
      }
    } catch (_) {
      // Malformed events are isolated from the rest of the realtime stream.
    }
  }

  void _startPing() {
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 25), (_) {
      final channel = _channel;
      if (channel == null || _intentionalDisconnect) return;
      try {
        channel.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        _handleTransportLoss();
      }
    });
  }

  void _handleTransportLoss() {
    _ping?.cancel();
    _ping = null;
    _connected = false;
    if (!_intentionalDisconnect) _setStatus(PyreHubStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || (_reconnect?.isActive ?? false)) return;

    const seconds = [2, 4, 8, 16, 30];
    final index = _reconnectAttempt.clamp(0, seconds.length - 1);
    final delay = Duration(
      seconds: seconds[index],
      milliseconds: _random.nextInt(600),
    );
    _reconnectAttempt++;
    _setStatus(PyreHubStatus.reconnecting);
    _reconnect = Timer(delay, _open);
  }

  Future<void> _closeTransport() async {
    _ping?.cancel();
    _ping = null;
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
    _setStatus(PyreHubStatus.disconnected);
  }
}
