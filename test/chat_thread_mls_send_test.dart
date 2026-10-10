import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/chats/chat_thread_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/services/pyre_mls.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

class _DisconnectedHub extends PyreHub {
  @override
  PyreHubStatus get status => PyreHubStatus.disconnected;

  @override
  bool sendTyping({required String conversationId, required bool active}) => false;
}

class _RecoveryMlsManager implements PyreMlsConversationManager {
  _RecoveryMlsManager(this.conversation);
  final _FakePrivateConversation conversation;
  bool ready = false;
  int attempts = 0;

  @override
  Future<PyreMlsOpenResult> openConversation({
    required PyreClient client,
    required String userId,
    required String chatId,
  }) async {
    attempts += 1;
    return ready
        ? PyreMlsOpenResult(supported: true, conversation: conversation)
        : const PyreMlsOpenResult(
            supported: true,
            waitingReason: 'Waiting for peer encryption setup',
          );
  }
}

class _ConnectedHub extends PyreHub {
  @override
  PyreHubStatus get status => PyreHubStatus.connected;

  @override
  bool sendTyping({
    required String conversationId,
    required bool active,
  }) =>
      true;
}

class _FakePrivateConversation implements PyrePrivateConversationCodec {
  String? encryptedPlaintext;

  @override
  String get chatId => 'chat-1';

  @override
  String get userId => 'me';

  @override
  String get deviceId => 'device-1';

  @override
  String newClientMessageId() => 'client-message-id-00000001';

  @override
  Future<String> encryptForSend({
    required String messageId,
    required String plaintext,
  }) async {
    encryptedPlaintext = plaintext;
    return 'Y2lwaGVydGV4dA==';
  }

  @override
  Future<String?> decryptMessage({
    required String messageId,
    required String ciphertext,
    required bool sentByMe,
  }) async =>
      null;

  @override
  Future<void> cachePlaintext(String messageId, String plaintext) async {}

  @override
  Future<({bool allReady, bool legacyPlaintextPurged})> markLegacyReady(
    PyreClient client,
  ) async =>
      (allReady: false, legacyPlaintextPurged: false);

  @override
  Future<void> close() async {}
}

class _FakeMlsManager implements PyreMlsConversationManager {
  _FakeMlsManager(this.conversation);

  final _FakePrivateConversation conversation;

  @override
  Future<PyreMlsOpenResult> openConversation({
    required PyreClient client,
    required String userId,
    required String chatId,
  }) async =>
      PyreMlsOpenResult(
        supported: true,
        conversation: conversation,
      );
}

class UnavailableMlsManager implements PyreMlsConversationManager {
  @override
  Future<PyreMlsOpenResult> openConversation({
    required PyreClient client,
    required String userId,
    required String chatId,
  }) async => const PyreMlsOpenResult(
        supported: true,
        waitingReason: 'Waiting for encrypted peer',
      );
}

class _RecordingClient extends PyreClient {
  int plaintextSends = 0;
  int encryptedSends = 0;
  String? ciphertext;

  @override
  Future<List<ChatMessage>> messages(String chatId) async => const [];

  @override
  Future<String> sendMessage({
    required String chatId,
    required String text,
    String? clientId,
  }) async {
    plaintextSends += 1;
    return clientId ?? 'plain-server-id';
  }

  @override
  Future<String> sendMlsMessage({
    required String chatId,
    required String ciphertext,
    required String clientId,
  }) async {
    encryptedSends += 1;
    this.ciphertext = ciphertext;
    return clientId;
  }
}

class _TransientFailureClient extends _RecordingClient {
  int attempts = 0;
  final attemptedIds = <String>[];
  final attemptedCiphertexts = <String>[];

  @override
  Future<String> sendMlsMessage({
    required String chatId,
    required String ciphertext,
    required String clientId,
  }) async {
    attempts += 1;
    attemptedIds.add(clientId);
    attemptedCiphertexts.add(ciphertext);
    if (attempts == 1) {
      throw PyreApiException('Temporary outage', 503);
    }
    return super.sendMlsMessage(
      chatId: chatId,
      ciphertext: ciphertext,
      clientId: clientId,
    );
  }
}

class _FallbackClient extends _RecordingClient {
  bool e2eeEnabled = false;
  int checks = 0;

  @override
  Future<bool> isChatEndToEndEncrypted(String chatId) async {
    checks += 1;
    return e2eeEnabled;
  }
}

void main() {
  testWidgets('direct thread sends MLS ciphertext when conversation is ready',
      (tester) async {
    const me = PyreUser(
      id: 'me',
      username: 'max',
      displayName: 'Max',
    );
    final client = _RecordingClient();
    final conversation = _FakePrivateConversation();

    await tester.pumpWidget(
      MaterialApp(
        theme: pyreTheme(),
        home: ChatThreadScreen(
          chatId: 'chat-1',
          peerUserId: 'friend-1',
          hub: _ConnectedHub(),
          title: 'Friend',
          me: me,
          client: client,
          encryptionKeyManager: _FakeMlsManager(conversation),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).last, 'secret hello');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(conversation.encryptedPlaintext, 'secret hello');
    expect(client.encryptedSends, 1);
    expect(client.ciphertext, 'Y2lwaGVydGV4dA==');
    expect(client.plaintextSends, 0);

    await tester.pump(const Duration(milliseconds: 800));
  });
  testWidgets('private HTTP send works while activity WebSocket is offline',
      (tester) async {
    const me = PyreUser(id: 'me', username: 'max', displayName: 'Max');
    final client = _RecordingClient();
    final codec = _FakePrivateConversation();
    await tester.pumpWidget(MaterialApp(
      theme: pyreTheme(),
      home: ChatThreadScreen(
        chatId: 'chat-1',
        peerUserId: 'friend-1',
        hub: _DisconnectedHub(),
        title: 'Friend',
        me: me,
        client: client,
        encryptionKeyManager: _FakeMlsManager(codec),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField).last, 'websocket not needed');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump(const Duration(milliseconds: 120));

    expect(client.encryptedSends, 1);
    expect(client.plaintextSends, 0);
    expect(codec.encryptedPlaintext, 'websocket not needed');
    // Drain the sender's deferred read-after-write reconciliation timer.
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('waiting private message retries automatically after MLS setup',
      (tester) async {
    const me = PyreUser(id: 'me', username: 'max', displayName: 'Max');
    final client = _RecordingClient();
    final codec = _FakePrivateConversation();
    final manager = _RecoveryMlsManager(codec);
    await tester.pumpWidget(MaterialApp(
      theme: pyreTheme(),
      home: ChatThreadScreen(
        chatId: 'chat-1',
        peerUserId: 'friend-1',
        hub: _DisconnectedHub(),
        title: 'Friend',
        me: me,
        client: client,
        encryptionKeyManager: manager,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField).last, 'send when ready');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(client.encryptedSends, 0);
    expect(client.plaintextSends, 0);
    expect(manager.attempts, greaterThanOrEqualTo(1));

    manager.ready = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 150));
    expect(client.encryptedSends, 1);
    expect(client.plaintextSends, 0);
    expect(codec.encryptedPlaintext, 'send when ready');
  });

  testWidgets('temporary server error retries with the same private message id',
      (tester) async {
    const me = PyreUser(id: 'me', username: 'max', displayName: 'Max');
    final client = _TransientFailureClient();
    final codec = _FakePrivateConversation();
    await tester.pumpWidget(MaterialApp(
      theme: pyreTheme(),
      home: ChatThreadScreen(
        chatId: 'chat-1',
        peerUserId: 'friend-1',
        hub: _DisconnectedHub(),
        title: 'Friend',
        me: me,
        client: client,
        encryptionKeyManager: _FakeMlsManager(codec),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField).last, 'reliable message');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(client.attempts, 1);
    expect(client.plaintextSends, 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 850));
    expect(client.attempts, 2);
    expect(client.encryptedSends, 1);
    expect(client.plaintextSends, 0);
    expect(client.attemptedIds[0], client.attemptedIds[1]);
    expect(client.attemptedCiphertexts[0], client.attemptedCiphertexts[1]);
  });

  testWidgets('standard messaging requires explicit per-message consent',
      (tester) async {
    const me = PyreUser(id: 'me', username: 'max', displayName: 'Max');
    final client = _FallbackClient();
    final codec = _FakePrivateConversation();
    final manager = _RecoveryMlsManager(codec);
    await tester.pumpWidget(MaterialApp(
      theme: pyreTheme(),
      home: ChatThreadScreen(
        chatId: 'chat-1', peerUserId: 'friend-1',
        hub: _DisconnectedHub(), title: 'Friend',
        me: me, client: client, encryptionKeyManager: manager,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField).last, 'fallback check');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(client.plaintextSends, 0);
    expect(find.text('Send standard'), findsOneWidget);
    await tester.tap(find.text('Send standard'));
    await tester.pump();
    expect(find.text('Send without end-to-end encryption?'), findsOneWidget);
    expect(client.plaintextSends, 0);
    await tester.tap(find.text('Keep private'));
    await tester.pump();
    expect(client.plaintextSends, 0);
    await tester.tap(find.text('Send standard'));
    await tester.pump();
    await tester.tap(find.text('Send standard').last);
    await tester.pump(const Duration(milliseconds: 250));

    expect(client.plaintextSends, 1);
    expect(client.encryptedSends, 0);
    expect(client.checks, 2);
    expect(find.byIcon(Icons.lock_open_rounded), findsWidgets);
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('established encrypted conversation forbids standard downgrade',
      (tester) async {
    const me = PyreUser(id: 'me', username: 'max', displayName: 'Max');
    final client = _FallbackClient()..e2eeEnabled = true;
    final codec = _FakePrivateConversation();
    await tester.pumpWidget(MaterialApp(
      theme: pyreTheme(),
      home: ChatThreadScreen(
        chatId: 'chat-1', peerUserId: 'friend-1',
        hub: _DisconnectedHub(), title: 'Friend', me: me,
        client: client, encryptionKeyManager: _RecoveryMlsManager(codec),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField).last, 'must remain private');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Send standard'));
    await tester.pump();
    expect(find.text('Send without end-to-end encryption?'), findsNothing);
    expect(client.plaintextSends, 0);
    expect(client.encryptedSends, 0);
  });

}
