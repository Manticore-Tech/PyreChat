import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/screens/chats/chat_thread_screen.dart';

ChatMessage message(Map<String, dynamic> extra) => ChatMessage.fromJson({
  'id': 'message-id-00000000000001',
  'sender_id': 'alice',
  'kind': 'mls',
  'body': 'encrypted-packet',
  'created_at': '2026-10-09T12:00:00.000Z',
  'username': 'alice',
  ...extra,
});

void main() {
  test('server acceptance is one check, not recipient delivery', () {
    final m = message({});
    expect(receiptKind(m), MessageReceiptKind.sent);
    expect(m.encrypted, isTrue);
    expect(m.deliveredAt, isNull);
    expect(m.readAt, isNull);
  });

  test('recipient acknowledgment produces double-check status', () {
    final m = message({'delivered_at': '2026-10-09T12:00:05.000Z'});
    expect(receiptKind(m), MessageReceiptKind.delivered);
    expect(m.readAt, isNull);
  });

  test('reading produces highlighted double-check status', () {
    final m = message({
      'delivered_at': '2026-10-09T12:00:05.000Z',
      'read_at': '2026-10-09T12:00:06.000Z',
    });
    expect(receiptKind(m), MessageReceiptKind.read);
    final restored = ChatMessage.fromJson(m.toCacheJson());
    expect(restored.encrypted, isTrue);
    expect(receiptKind(restored), MessageReceiptKind.read);
  });

  test('encryption is independent of delivery and read', () {
    final standard = message({
      'kind': 'text',
      'body': 'ordinary text',
      'delivered_at': '2026-10-09T12:00:05.000Z',
      'read_at': '2026-10-09T12:00:06.000Z',
    });
    expect(standard.encrypted, isFalse);
    expect(receiptKind(standard), MessageReceiptKind.read);
  });

  test('pending and failed messages cannot become delivered by default', () {
    final pending = message({'delivery_state': 'queued'});
    expect(pending.deliveryState, ChatDeliveryState.queued);
    expect(pending.deliveredAt, isNull);
  });
}
