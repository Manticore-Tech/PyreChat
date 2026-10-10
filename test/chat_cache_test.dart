import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/services/chat_cache.dart';
import 'package:pyrechat_flutter/services/secure_blob_store.dart';

class _FakeSecureBlobStore implements SecureBlobStore {
  _FakeSecureBlobStore({this.supported = true});

  final bool supported;
  final Map<String, String> values = {};

  @override
  Future<bool> get isSupported async => supported;

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<bool> write(String name, String value) async {
    if (!supported) return false;
    values[name] = value;
    return true;
  }

  @override
  Future<void> delete(String name) async {
    values.remove(name);
  }
}

void main() {
  test('chat list round-trips through secure cache', () async {
    final store = _FakeSecureBlobStore();
    final cache = ChatCache(store: store);

    const chats = [
      ChatPreview(
        id: 'chat-1',
        title: 'Meredith',
        preview: 'saved locally',
        timeLabel: '2m',
        unread: 3,
        avatarInitials: 'M',
        avatarHue: 42,
        avatarUserId: 'friend-1',
        avatarUrl: 'https://example.invalid/avatar.jpg',
        lastKind: 'text',
        lastSenderId: 'friend-1',
        muted: true,
        memberIds: ['me', 'friend-1'],
      ),
    ];

    await cache.writeChats('me', chats);
    final restored = await cache.readChats('me');

    expect(restored, isNotNull);
    expect(restored, hasLength(1));
    expect(restored!.single.id, 'chat-1');
    expect(restored.single.title, 'Meredith');
    expect(restored.single.preview, 'saved locally');
    expect(restored.single.unread, 3);
    expect(restored.single.muted, isTrue);
    expect(restored.single.memberIds, ['me', 'friend-1']);
  });

  test('cached in-flight messages restore as queued messages', () async {
    final store = _FakeSecureBlobStore();
    final cache = ChatCache(store: store);

    const message = ChatMessage(
      id: 'tmp-1',
      senderId: 'me',
      kind: 'text',
      body: 'queue me',
      createdAt: '2026-09-29T12:00:00Z',
      displayName: 'Max',
      username: 'max',
      deliveryState: ChatDeliveryState.sending,
      localEcho: true,
    );

    await cache.writeMessages('me', 'chat-1', const [message]);
    final restored = await cache.readMessages('me', 'chat-1');

    expect(restored, isNotNull);
    expect(restored, hasLength(1));
    expect(restored!.single.body, 'queue me');
    expect(restored.single.deliveryState, ChatDeliveryState.queued);
    expect(restored.single.localEcho, isTrue);
  });

  test('empty lists are cached as real offline state', () async {
    final store = _FakeSecureBlobStore();
    final cache = ChatCache(store: store);

    await cache.writeChats('me', const []);
    await cache.writeMessages('me', 'chat-empty', const []);

    expect(await cache.readChats('me'), isEmpty);
    expect(await cache.readMessages('me', 'chat-empty'), isEmpty);
  });

  test('unsupported secure storage fails closed', () async {
    final store = _FakeSecureBlobStore(supported: false);
    final cache = ChatCache(store: store);

    await cache.writeChats(
      'me',
      const [
        ChatPreview(
          id: 'chat-1',
          title: 'Chat',
          preview: 'private',
          timeLabel: '',
        ),
      ],
    );

    expect(store.values, isEmpty);
    expect(await cache.readChats('me'), isNull);
  });

  test('clearing a user removes list and known thread caches', () async {
    final store = _FakeSecureBlobStore();
    final cache = ChatCache(store: store);

    await cache.writeChats(
      'me',
      const [
        ChatPreview(
          id: 'chat-1',
          title: 'Chat',
          preview: '',
          timeLabel: '',
        ),
      ],
    );
    await cache.writeMessages(
      'me',
      'chat-1',
      const [
        ChatMessage(
          id: 'm1',
          senderId: 'friend',
          kind: 'text',
          body: 'private',
          createdAt: '2026-09-29T12:00:00Z',
          displayName: 'Friend',
          username: 'friend',
        ),
      ],
    );

    await cache.clearUser('me');

    expect(await cache.readChats('me'), isNull);
    expect(await cache.readMessages('me', 'chat-1'), isNull);
  });
}
