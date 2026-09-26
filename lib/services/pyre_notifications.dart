import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class PyreNotificationBackend {
  Future<void> init();

  Future<bool> show({
    required String title,
    required String body,
    String? payload,
  });
}

class PlatformPyreNotificationBackend implements PyreNotificationBackend {
  const PlatformPyreNotificationBackend();

  static const MethodChannel _channel =
      MethodChannel('dev.pyrearms.pyrechat/notifications');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> init() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('initNotifications');
    } on MissingPluginException {
      // Platform backend is not wired on this target yet.
    } on PlatformException {
      // Notification permission/channel failure must not break the app.
    }
  }

  @override
  Future<bool> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'showNotification',
            <String, Object?>{
              'title': title,
              'body': body,
              if (payload != null) 'payload': payload,
            },
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Notification facade used by realtime events.
///
/// Private message text is intentionally not copied into notification content.
/// The backend receives only generic activity labels until encrypted push and
/// user-configurable preview policy exist.
class PyreNotifications {
  PyreNotifications._({
    PyreNotificationBackend backend =
        const PlatformPyreNotificationBackend(),
  }) : _backend = backend;

  @visibleForTesting
  PyreNotifications.forTesting(PyreNotificationBackend backend)
      : _backend = backend;

  static final PyreNotifications instance = PyreNotifications._();

  final PyreNotificationBackend _backend;
  var _ready = false;

  Future<void> init() async {
    // Mark ready first so a realtime event arriving during the native permission
    // prompt is not permanently dropped by the Dart facade.
    _ready = true;
    await _backend.init();
  }

  Future<bool> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return false;
    return _backend.show(title: title, body: body, payload: payload);
  }

  void handleHubEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final kind = event['kind'] as String?;

    if (type == 'pyre' || kind == 'pyre' || type == 'pyre_presence') {
      return;
    }

    if (type == 'chat') {
      show(title: 'PyreChat', body: 'New message');
      return;
    }
    if (type == 'snap' || kind == 'snap') {
      show(title: 'PyreChat', body: 'New Pyre');
      return;
    }
    if (type == 'notification' &&
        (kind == 'friend' || kind == 'friend_request')) {
      show(title: 'PyreChat', body: 'Friend activity');
    }
  }
}
