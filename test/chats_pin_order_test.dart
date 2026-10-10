import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/chats/chats_screen.dart';
import 'package:pyrechat_flutter/services/chat_order_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/chat_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OrderedChatsClient extends PyreClient {
  @override
  Future<List<ChatPreview>> chats() async => const [
        ChatPreview(
          id: 'newest',
          title: 'Newest',
          preview: 'Just arrived',
          timeLabel: 'now',
          avatarInitials: 'N',
        ),
        ChatPreview(
          id: 'second',
          title: 'Second',
          preview: 'Recently',
          timeLabel: '2m',
          avatarInitials: 'S',
        ),
        ChatPreview(
          id: 'third',
          title: 'Third',
          preview: 'Earlier',
          timeLabel: '1h',
          avatarInitials: 'T',
        ),
        ChatPreview(
          id: 'fourth',
          title: 'Fourth',
          preview: 'Yesterday',
          timeLabel: '1d',
          avatarInitials: 'F',
        ),
        ChatPreview(
          id: 'oldest',
          title: 'Oldest',
          preview: 'Last week',
          timeLabel: '7d',
          avatarInitials: 'O',
        ),
      ];
}

void main() {
  testWidgets('pin buckets retain server recency order within each bucket',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = ChatOrderPrefs();
    await prefs.setPosition('second', ChatPinPosition.top);
    await prefs.setPosition('third', ChatPinPosition.top);
    await prefs.setPosition('oldest', ChatPinPosition.bottom);

    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    const user = PyreUser(
      id: 'me',
      username: 'me',
      displayName: 'Me',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: pyreTheme(),
        home: ChatsScreen(
          hub: PyreHub(),
          user: user,
          client: _OrderedChatsClient(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final orderedIds = tester
        .widgetList<ChatRow>(find.byType(ChatRow))
        .map((row) => row.chat.id)
        .toList(growable: false);
    expect(orderedIds, ['second', 'third', 'newest', 'fourth', 'oldest']);
    expect(tester.takeException(), isNull);
  });
}
