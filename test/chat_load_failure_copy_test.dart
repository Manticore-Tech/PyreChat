import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';

void main() {
  test('untrusted server errors never become chat load feedback', () {
    const internal = 'database connection refused: private table message_keys';
    for (final status in [400, 500, 502, 503, 504, 418]) {
      final safe = PyreApiException(internal, status).safeChatLoadMessage;
      expect(safe, isNot(contains(internal)));
      expect(safe, isNot(contains('message_keys')));
    }
    expect(
      PyreApiException(internal, 418).safeChatLoadMessage,
      'Could not load messages. Try again.',
    );
  });

  test('chat load failures give bounded, actionable status guidance', () {
    expect(
      PyreApiException('token=secret', null).safeChatLoadMessage,
      'Could not connect. Check your internet connection and try again.',
    );
    expect(
      PyreApiException('token=secret', 401).safeChatLoadMessage,
      'Your session expired. Sign in again.',
    );
    expect(
      PyreApiException('backend acl info', 403).safeChatLoadMessage,
      'You no longer have access to this conversation.',
    );
    expect(
      PyreApiException('backend acl info', 404).safeChatLoadMessage,
      'This conversation is no longer available.',
    );
    expect(
      PyreApiException('quota internals', 429).safeChatLoadMessage,
      'Too many requests. Try again shortly.',
    );
    expect(
      PyreApiException('sql stack trace', 503).safeChatLoadMessage,
      'Service temporarily unavailable. Try again shortly.',
    );
  });
}
