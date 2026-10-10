import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';

class _FriendsClient extends PyreClient {
  @override
  Future<FriendAddsBundle> friendAdds() async => const FriendAddsBundle(
        incoming: [],
        sent: [],
        hidden: [],
        deleted: [],
        suggestions: [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('invite confirms only after clipboard write succeeds',
      (tester) async {
    final copyFinished = Completer<void>();
    String? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method != 'Clipboard.setData') return null;
      copied = (call.arguments as Map)['text'] as String?;
      await copyFinished.future;
      return null;
    });
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: _FriendsClient())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite your friends!'));
    await tester.pump();
    expect(find.text('Invite link copied'), findsNothing);
    expect(copied, contains('https://pyre.social'));

    copyFinished.complete();
    await tester.pumpAndSettle();
    expect(find.text('Invite link copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invite reports clipboard failure instead of false success',
      (tester) async {
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard_unavailable');
      }
      return null;
    });
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: _FriendsClient())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite your friends!'));
    await tester.pumpAndSettle();
    expect(find.text('Could not copy invite link. Try again.'), findsOneWidget);
    expect(find.text('Invite link copied'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
