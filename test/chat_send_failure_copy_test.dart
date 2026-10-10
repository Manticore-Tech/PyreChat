import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';

void main() {
  test('untrusted API errors never surface raw backend internals', () {
    const internal = 'database connection refused: private table message_keys';
    expect(
      PyreApiException(internal, 500).safeChatSendMessage,
      'Service temporarily unavailable. Try again shortly.',
    );
    expect(
      PyreApiException(internal, 418).safeChatSendMessage,
      'Message could not be sent. Try again.',
    );
  });

  test('known send failures provide actionable, bounded feedback', () {
    expect(
      PyreApiException('sensitive backend details', 401).safeChatSendMessage,
      'Your session expired. Sign in again.',
    );
    expect(
      PyreApiException('sensitive backend details', 403).safeChatSendMessage,
      'You cannot send messages in this conversation.',
    );
    expect(
      PyreApiException('sensitive backend details', 429).safeChatSendMessage,
      'Too many messages. Try again shortly.',
    );
  });

  test('only the locally defined private setup message is passed through', () {
    const trusted = 'Private messaging is still setting up. Try again in a moment.';
    expect(PyreApiException(trusted, 409).safeChatSendMessage, trusted);
    expect(
      PyreApiException('internal MLS group state 999', 409).safeChatSendMessage,
      'Conversation is still syncing. Try again shortly.',
    );
  });

  test('unexpected transport-status errors do not leak details', () {
    expect(
      PyreApiException('exception with private token', null).safeChatSendMessage,
      'Message could not be sent. Try again.',
    );
  });
}
