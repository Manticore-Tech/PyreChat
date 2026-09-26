import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/services/chat_message_merge.dart';

ChatMessage message(
  String id, {
  ChatDeliveryState deliveryState = ChatDeliveryState.delivered,
  bool localEcho = false,
  String createdAt = '2026-09-25T20:00:00Z',
}) {
  return ChatMessage(
    id: id,
    senderId: 'me',
    kind: 'text',
    body: 'hello',
    createdAt: createdAt,
    displayName: 'Me',
    username: 'me',
    deliveryState: deliveryState,
    localEcho: localEcho,
  );
}

void main() {
  test('keeps an optimistic send when a refresh has not seen it yet', () {
    final pending = message(
      'tmp-1',
      deliveryState: ChatDeliveryState.sending,
      localEcho: true,
    );

    final merged = mergeThreadMessages(remote: const [], current: [pending]);

    expect(merged.map((m) => m.id), ['tmp-1']);
    expect(merged.single.deliveryState, ChatDeliveryState.sending);
  });

  test('server copy replaces the matching acknowledged local echo', () {
    final echo = message('server-1', localEcho: true);
    final remote = message('server-1');

    final merged = mergeThreadMessages(remote: [remote], current: [echo]);

    expect(merged, hasLength(1));
    expect(merged.single.id, 'server-1');
    expect(merged.single.localEcho, isFalse);
  });

  test('failed messages survive unrelated live refreshes for retry', () {
    final failed = message(
      'tmp-failed',
      deliveryState: ChatDeliveryState.failed,
      localEcho: true,
      createdAt: '2026-09-25T20:00:01Z',
    );
    final remote = message('older', createdAt: '2026-09-25T19:59:00Z');

    final merged = mergeThreadMessages(remote: [remote], current: [failed]);

    expect(merged.map((m) => m.id), ['older', 'tmp-failed']);
    expect(merged.last.deliveryState, ChatDeliveryState.failed);
  });
}
