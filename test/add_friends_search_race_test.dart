import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

class _DeferredSearchClient extends PyreClient {
  final pending = <String, Completer<List<PyreFriend>>>{};

  @override
  Future<FriendAddsBundle> friendAdds() async => const FriendAddsBundle(
        incoming: [],
        sent: [],
        hidden: [],
        deleted: [],
        suggestions: [],
      );

  @override
  Future<List<PyreFriend>> searchUsers(String query) {
    final request = Completer<List<PyreFriend>>();
    pending[query] = request;
    return request.future;
  }
}

Future<void> _openPhone(WidgetTester tester, PyreClient client) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(720, 1480);
  await tester.pumpWidget(
    MaterialApp(
      theme: pyreTheme(),
      home: AddFriendsScreen(client: client),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('newer friend search wins when older request finishes last',
      (tester) async {
    final client = _DeferredSearchClient();
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await _openPhone(tester, client);
    final search = find.byType(TextField).first;

    await tester.enterText(search, 'al');
    await tester.pump(const Duration(milliseconds: 260));
    expect(client.pending.containsKey('al'), isTrue);

    await tester.enterText(search, 'alex');
    await tester.pump(const Duration(milliseconds: 260));
    expect(client.pending.containsKey('alex'), isTrue);

    client.pending['alex']!.complete(const [
      PyreFriend(id: 'new', username: 'alex', displayName: 'Current Alex'),
    ]);
    await tester.pump();
    expect(find.text('Current Alex'), findsOneWidget);

    client.pending['al']!.complete(const [
      PyreFriend(id: 'old', username: 'al', displayName: 'Stale Al'),
    ]);
    await tester.pump();
    expect(find.text('Current Alex'), findsOneWidget);
    expect(find.text('Stale Al'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing search hides spinner and ignores a late response',
      (tester) async {
    final client = _DeferredSearchClient();
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await _openPhone(tester, client);
    final search = find.byType(TextField).first;

    await tester.enterText(search, 'taylor');
    await tester.pump(const Duration(milliseconds: 260));
    expect(client.pending.containsKey('taylor'), isTrue);

    await tester.enterText(search, '');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Search by username'), findsOneWidget);

    client.pending['taylor']!.complete(const [
      PyreFriend(id: 'old', username: 'taylor', displayName: 'Stale Taylor'),
    ]);
    await tester.pump();
    expect(find.text('Stale Taylor'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
