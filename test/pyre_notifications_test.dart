import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_notifications.dart';

class _ShownNotification {
  const _ShownNotification(this.title, this.body, this.payload);

  final String title;
  final String body;
  final String? payload;
}

class _FakeNotificationBackend implements PyreNotificationBackend {
  var initialized = false;
  final shown = <_ShownNotification>[];

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  Future<bool> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add(_ShownNotification(title, body, payload));
    return true;
  }
}

void main() {
  test('notification facade does nothing before initialization', () async {
    final backend = _FakeNotificationBackend();
    final notifications = PyreNotifications.forTesting(backend);

    expect(
      await notifications.show(title: 'PyreChat', body: 'New message'),
      isFalse,
    );
    expect(backend.shown, isEmpty);
  });

  test('chat notification never copies private message text', () async {
    final backend = _FakeNotificationBackend();
    final notifications = PyreNotifications.forTesting(backend);
    await notifications.init();

    notifications.handleHubEvent({
      'type': 'chat',
      'body': 'private plaintext that must not reach the lock screen',
    });

    expect(backend.initialized, isTrue);
    expect(backend.shown, hasLength(1));
    expect(backend.shown.single.title, 'PyreChat');
    expect(backend.shown.single.body, 'New message');
    expect(
      backend.shown.single.body,
      isNot(contains('private plaintext')),
    );
  });

  test('snap and friend activity use generic notification labels', () async {
    final backend = _FakeNotificationBackend();
    final notifications = PyreNotifications.forTesting(backend);
    await notifications.init();

    notifications.handleHubEvent({
      'type': 'snap',
      'body': 'sensitive caption',
    });
    notifications.handleHubEvent({
      'type': 'notification',
      'kind': 'friend_request',
      'body': 'server supplied friend text',
    });

    expect(
      backend.shown.map((notification) => notification.body),
      ['New Pyre', 'Friend activity'],
    );
  });

  test('unrecognized realtime events do not notify', () async {
    final backend = _FakeNotificationBackend();
    final notifications = PyreNotifications.forTesting(backend);
    await notifications.init();

    notifications.handleHubEvent({'type': 'pong'});
    notifications.handleHubEvent({'type': 'presence'});
    notifications.handleHubEvent({'type': 'pyre', 'body': 'room message'});
    notifications.handleHubEvent({'type': 'pyre_presence', 'kind': 'join'});

    expect(backend.shown, isEmpty);
  });
}
