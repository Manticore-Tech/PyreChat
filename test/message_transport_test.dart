import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/message_transport.dart';

void main() {
  test('legacy messaging adapter preserves production routes and receipt semantics', () async {
    final gets = <String>[];
    final posts = <(String, Map<String, dynamic>)>[];
    var encrypted = true;
    final adapter = LegacyPyreMessageTransport(
      get: (path) async {
        gets.add(path);
        if (path.endsWith('/encryption')) return {'e2eeEnabled': encrypted};
        return {'messages': []};
      },
      post: (path, payload) async {
        posts.add((path, payload));
        return {'id': 'receipt-id'};
      },
    );

    expect(await adapter.messages('chat-1'), isEmpty);
    expect(await adapter.isEncrypted('chat-1'), isTrue);
    expect(gets, [
      '/api/chats/chat-1/messages',
      '/api/chats/chat-1/encryption',
    ]);

    await adapter.acknowledge(
      chatId: 'chat-1',
      messageIds: [],
      read: false,
    );
    expect(posts, isEmpty);
    await adapter.acknowledge(
      chatId: 'chat-1',
      messageIds: ['message-1'],
      read: true,
    );
    expect(posts.single.$1, '/api/chats/chat-1/receipts');
    expect(posts.single.$2, {
      'messageIds': ['message-1'],
      'read': true,
    });

    encrypted = false;
    expect(await adapter.sendText(
      chatId: 'chat-1',
      text: 'Hello',
      clientId: 'client-123',
    ), 'receipt-id');
    expect(posts.last.$2, {
      'kind': 'text',
      'body': 'Hello',
      'clientId': 'client-123',
    });

    expect(await adapter.sendEncrypted(
      chatId: 'chat-1',
      ciphertext: 'Y2lwaGVydGV4dA==',
      clientId: 'encrypted-123',
    ), 'receipt-id');
    expect(posts.last.$2, {
      'kind': 'mls',
      'body': 'Y2lwaGVydGV4dA==',
      'clientId': 'encrypted-123',
    });
  });

  test('standard send fails closed when the chat has MLS encryption', () async {
    final sent = <Map<String, dynamic>>[];
    final adapter = LegacyPyreMessageTransport(
      get: (_) async => {'e2eeEnabled': true},
      post: (_, payload) async {
        sent.add(payload);
        return {'id': 'should-not-send'};
      },
    );

    await expectLater(
      adapter.sendText(chatId: 'protected', text: 'private message'),
      throwsStateError,
    );
    expect(sent, isEmpty);
  });

  test('chat IDs cannot inject route segments or query parameters', () async {
    final routes = <String>[];
    final chatId = 'room/next?limit=100';
    final base = '/api/chats/room%2Fnext%3Flimit%3D100';
    final adapter = LegacyPyreMessageTransport(
      get: (path) async {
        routes.add(path);
        return {'e2eeEnabled': false, 'messages': []};
      },
      post: (path, payload) async {
        routes.add(path);
        return {'id': 'sent'};
      },
    );

    await adapter.messages(chatId);
    await adapter.acknowledge(
      chatId: chatId,
      messageIds: ['one'],
      read: false,
    );
    await adapter.sendText(chatId: chatId, text: 'hello');
    await adapter.sendEncrypted(
      chatId: chatId,
      ciphertext: 'Y2lwaGVydGV4dA==',
      clientId: 'mls-1',
    );
    expect(routes, [
      '$base/messages',
      '$base/receipts',
      '$base/encryption',
      '$base/messages',
      '$base/messages',
    ]);
  });

  test('unknown encryption status never permits plaintext fallback', () async {
    var encryptionStatus = <String, dynamic>{};
    final posts = <Map<String, dynamic>>[];
    final adapter = LegacyPyreMessageTransport(
      get: (_) async => encryptionStatus,
      post: (_, payload) async {
        posts.add(payload);
        return {'id': 'safe-plaintext'};
      },
    );

    for (final invalidStatus in <Map<String, dynamic>>[
      {},
      {'e2eeEnabled': null},
      {'e2eeEnabled': 'false'},
      {'e2eeEnabled': 0},
    ]) {
      encryptionStatus = invalidStatus;
      await expectLater(
        adapter.sendText(chatId: 'chat-1', text: 'must-not-leak'),
        throwsStateError,
      );
    }
    expect(posts, isEmpty);

    // Confirm an explicitly unencrypted chat can still send normally.
    encryptionStatus = {'e2eeEnabled': false};
    expect(
      await adapter.sendText(chatId: 'chat-1', text: 'allowed'),
      'safe-plaintext',
    );
    expect(posts, hasLength(1));
    expect(posts.single['body'], 'allowed');
  });

  test('failed MLS send never retries over standard/plaintext messaging', () async {
    final calls = <Map<String, dynamic>>[];
    final adapter = LegacyPyreMessageTransport(
      get: (_) async => {},
      post: (_, payload) async {
        calls.add(payload);
        throw StateError('MLS backend unavailable');
      },
    );
    await expectLater(
      adapter.sendEncrypted(
        chatId: 'chat-1',
        ciphertext: 'Y2lwaGVydGV4dA==',
        clientId: 'encrypted-123',
      ),
      throwsStateError,
    );
    expect(calls, hasLength(1));
    expect(calls.single['kind'], 'mls');
  });
}
