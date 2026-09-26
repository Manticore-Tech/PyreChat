import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/session_events.dart';

void main() {
  test('session invalidation notifies active listeners', () {
    String? received;
    void listener(String message) => received = message;

    SessionEvents.instance.addInvalidatedListener(listener);
    addTearDown(() => SessionEvents.instance.removeInvalidatedListener(listener));

    SessionEvents.instance.invalidate('Sign in again');

    expect(received, 'Sign in again');
  });

  test('removed session listeners are not notified', () {
    var calls = 0;
    void listener(String message) => calls++;

    SessionEvents.instance.addInvalidatedListener(listener);
    SessionEvents.instance.removeInvalidatedListener(listener);
    SessionEvents.instance.invalidate();

    expect(calls, 0);
  });
}
