import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';

abstract class PyreNotificationBackend {
  Future<void> init();

  Future<String?> pushToken() async => null;

  Future<String?> takeLaunchConversationId() async => null;

  Future<void> setContext({
    required bool foreground,
    String? activeConversationId,
  }) async {}

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

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> init() async {
    if (!_isMobile) return;
    try {
      await _channel.invokeMethod<void>('initNotifications');
    } on MissingPluginException {
      // Platform backend is not wired on this target yet.
    } on PlatformException {
      // Notification permission/channel failure must not break the app.
    }
  }

  @override
  Future<String?> pushToken() async {
    if (!_isMobile) return null;
    try {
      final token = await _channel.invokeMethod<String?>('getPushToken');
      final trimmed = token?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<String?> takeLaunchConversationId() async {
    if (!_isMobile) return null;
    try {
      final value =
          await _channel.invokeMethod<String?>('takeNotificationConversationId');
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> setContext({
    required bool foreground,
    String? activeConversationId,
  }) async {
    if (!_isMobile) return;
    try {
      await _channel.invokeMethod<void>(
        'setNotificationContext',
        <String, Object?>{
          'foreground': foreground,
          'activeConversationId': activeConversationId,
        },
      );
    } on MissingPluginException {
      // Platform backend is not wired on this target.
    } on PlatformException {
      // Notification context is best-effort.
    }
  }

  @override
  Future<bool> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isMobile) return false;
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

enum PyreQuietModeLevel { off, quiet, absolute }

extension PyreQuietModeLevelWire on PyreQuietModeLevel {
  String get wireValue => switch (this) {
        PyreQuietModeLevel.off => 'off',
        PyreQuietModeLevel.quiet => 'quiet',
        PyreQuietModeLevel.absolute => 'absolute',
      };

  static PyreQuietModeLevel fromWire(String? value) => switch (value) {
        'quiet' => PyreQuietModeLevel.quiet,
        'absolute' => PyreQuietModeLevel.absolute,
        _ => PyreQuietModeLevel.off,
      };
}

class PyreQuietMode {
  PyreQuietMode._();

  static final PyreQuietMode instance = PyreQuietMode._();

  static const MethodChannel _channel =
      MethodChannel('dev.pyrearms.pyrechat/notifications');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> get isSupported async {
    if (!_isAndroid) return false;
    return _invokeBool('isQuietModeSupported');
  }

  Future<PyreQuietModeLevel> get level async {
    if (!_isAndroid) return PyreQuietModeLevel.off;
    try {
      final value = await _channel.invokeMethod<String>('getQuietModeLevel');
      return PyreQuietModeLevelWire.fromWire(value);
    } on MissingPluginException {
      return PyreQuietModeLevel.off;
    } on PlatformException {
      return PyreQuietModeLevel.off;
    }
  }

  Future<bool> get isEnabled async =>
      await level != PyreQuietModeLevel.off;

  Future<bool> get hasPolicyAccess async {
    if (!_isAndroid) return false;
    return _invokeBool('hasNotificationPolicyAccess');
  }

  Future<void> openPolicyAccessSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openNotificationPolicyAccessSettings');
    } on MissingPluginException {
      // Android host is not wired on this target.
    } on PlatformException {
      // Settings launch failures should not break the app.
    }
  }

  Future<bool> setLevel(PyreQuietModeLevel level) async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'setQuietModeLevel',
            <String, Object?>{'mode': level.wireValue},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) =>
      setLevel(enabled ? PyreQuietModeLevel.quiet : PyreQuietModeLevel.off);

  Future<bool> _invokeBool(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
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

  Future<void> setContext({
    required bool foreground,
    String? activeConversationId,
  }) =>
      _backend.setContext(
        foreground: foreground,
        activeConversationId: activeConversationId,
      );

  Future<String?> takeLaunchConversationId() =>
      _backend.takeLaunchConversationId();

  Future<bool> syncPushRegistration() async {
    if (!_ready) return false;
    final token = await _backend.pushToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('[PyrePush] No platform push token is available yet.');
      }
      return false;
    }
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      await PyreClient().registerPushToken(
        token: token,
        platform: platform,
      );
      if (kDebugMode) {
        debugPrint('[PyrePush] Push token registration succeeded.');
      }
      return true;
    } on PyreApiException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[PyrePush] Push token registration failed: '
          'status=${error.statusCode ?? 'none'} message=${error.message}',
        );
      }
      return false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PyrePush] Push token registration failed: $error');
      }
      return false;
    }
  }

  void handleHubEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final kind = event['kind'] as String?;

    if (type == 'pyre' || kind == 'pyre' || type == 'pyre_presence') {
      return;
    }

    final conversationId = (event['conversationId'] ??
            event['chatId'] ??
            event['conversation_id'])
        ?.toString()
        .trim();
    final payload = conversationId == null || conversationId.isEmpty
        ? null
        : jsonEncode({'conversationId': conversationId});

    if (type == 'chat') {
      show(title: 'PyreChat', body: 'New message', payload: payload);
      return;
    }
    if (type == 'snap' || kind == 'snap') {
      show(title: 'PyreChat', body: 'New Pyre', payload: payload);
      return;
    }
    if (type == 'notification' &&
        (kind == 'friend' || kind == 'friend_request')) {
      show(title: 'PyreChat', body: 'Friend activity');
    }
  }
}
