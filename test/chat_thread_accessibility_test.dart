import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/chats/chat_thread_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

class _FakeThreadClient extends PyreClient {
  @override
  Future<List<ChatMessage>> messages(String chatId) async => const [];

  @override
  Future<String> sendMessage({
    required String chatId,
    required String text,
    String? clientId,
  }) async {
    return 'server-message-id';
  }
}

class _FailedThreadClient extends _FakeThreadClient {
  @override
  Future<List<ChatMessage>> messages(String chatId) async => const [
        ChatMessage(
          id: 'tmp-failed',
          senderId: 'me',
          kind: 'text',
          body: 'Try again',
          createdAt: '2026-10-07T20:00:00Z',
          displayName: 'Max',
          username: 'max',
          deliveryState: ChatDeliveryState.failed,
          localEcho: true,
        ),
      ];
}

void main() {
  testWidgets('chat thread controls expose stable accessibility names',
      (tester) async {
    final semantics = tester.ensureSemantics();

    const me = PyreUser(
      id: 'me',
      username: 'max',
      displayName: 'Max',
    );
    final hub = PyreHub();

    await tester.pumpWidget(
      MaterialApp(
        theme: pyreTheme(),
        home: ChatThreadScreen(
          chatId: 'chat-1',
          hub: hub,
          title: 'Friend',
          me: me,
          client: _FailedThreadClient(),
          onGoCamera: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Back to chats'), findsOneWidget);
    expect(find.bySemanticsLabel('Open camera'), findsOneWidget);
    expect(find.bySemanticsLabel('Send message'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'hello');
    await tester.pump();

    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    semantics.dispose();
  });
}
