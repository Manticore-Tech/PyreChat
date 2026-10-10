import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/services/chat_outbox.dart';

ChatMessage message(
  String id, {
  String senderId = 'me',
  String kind = 'text',
  ChatDeliveryState deliveryState = ChatDeliveryState.queued,
  bool localEcho = true,
}) {
  return ChatMessage(
    id: id,
    senderId: senderId,
    kind: kind,
    body: 'hello',
    createdAt: '2026-09-29T12:00:00Z',
    displayName: 'Me',
    username: 'me',
    deliveryState: deliveryState,
    localEcho: localEcho,
  );
}

void main() {
  test('outbox selects only my queued local text messages', () {
    final queued = message('tmp-queued');
    final messages = [
      queued,
      message('tmp-failed', deliveryState: ChatDeliveryState.failed),
      message('tmp-sending', deliveryState: ChatDeliveryState.sending),
      message('tmp-remote', localEcho: false),
      message('tmp-other', senderId: 'friend'),
      message('tmp-snap', kind: 'snap'),
    ];

    final result = queuedTextMessagesForRetry(messages, senderId: 'me');

    expect(result, [queued]);
  });

  test('outbox preserves queue order', () {
    final first = message('tmp-1');
    final second = message('tmp-2');

    final result = queuedTextMessagesForRetry(
      [first, second],
      senderId: 'me',
    );

    expect(result.map((message) => message.id), ['tmp-1', 'tmp-2']);
  });
  test('outgoing ids are random and valid for encrypted idempotent sends', () {
    final ids = List.generate(128, (_) => newOutgoingClientMessageId());
    final valid = RegExp(r'^[A-Za-z0-9_-]{20,160}$');
    expect(ids.every((id) => valid.hasMatch(id)), isTrue);
    expect(ids.toSet().length, ids.length);
  });

}
