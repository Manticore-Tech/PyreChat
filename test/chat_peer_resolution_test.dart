import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/chat_peer_resolution.dart';

void main() {
  test('explicit direct peer metadata takes precedence over message history', () {
    expect(
      resolveDirectChatPeerId(
        meId: 'me',
        requiresPrivateText: true,
        peerUserId: ' peer ',
        messageSenderIds: const ['someone-else', 'me'],
      ),
      'peer',
    );
  });

  test('direct chat recovers safety target from received messages', () {
    expect(
      resolveDirectChatPeerId(
        meId: 'me',
        requiresPrivateText: true,
        messageSenderIds: const ['me', '', ' peer-id ', 'another'],
      ),
      'peer-id',
    );
  });

  test('a local-echo-only direct chat never targets the signed-in user', () {
    expect(
      resolveDirectChatPeerId(
        meId: 'me',
        requiresPrivateText: true,
        peerUserId: ' me ',
        messageSenderIds: const [' me ', '', '  '],
      ),
      isNull,
    );
  });

  test('group messages are never mistaken for a direct-chat safety target', () {
    expect(
      resolveDirectChatPeerId(
        meId: 'me',
        requiresPrivateText: false,
        messageSenderIds: const ['group-member'],
      ),
      isNull,
    );
  });
}
