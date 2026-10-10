import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';

class _SearchRequest {
  _SearchRequest(this.query);

  final String query;
  final completer = Completer<List<PyreFriend>>();
}

class _FriendsSearchClient extends PyreClient {
  final requests = <_SearchRequest>[];

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
    final request = _SearchRequest(query);
    requests.add(request);
    return request.completer.future;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('failed search offers retry, then clear returns to suggestions',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(640, 1136);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final client = _FriendsSearchClient();
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: client)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'phoenix');
    await tester.pump(const Duration(milliseconds: 300));
    expect(client.requests.single.query, 'phoenix');

    client.requests.single.completer.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('Search unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('No people match'), findsNothing);
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(client.requests.length, 2);
    expect(client.requests.last.query, 'phoenix');

    client.requests.last.completer.complete(const [
      PyreFriend(
        id: 'friend-1',
        username: 'phoenix_one',
        displayName: 'Phoenix One',
      ),
    ]);
    await tester.pump();

    expect(find.text('Phoenix One'), findsOneWidget);
    expect(find.text('Search unavailable'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.text('Invite your friends!'), findsOneWidget);
    expect(find.text('Search unavailable'), findsNothing);
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale failed search cannot hide newer successful matches',
      (tester) async {
    final client = _FriendsSearchClient();
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: client)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 300));
    expect(client.requests.length, 1);

    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 300));
    expect(client.requests.length, 2);

    client.requests.last.completer.complete(const [
      PyreFriend(
        id: 'friend-2',
        username: 'new_friend',
        displayName: 'New Friend',
      ),
    ]);
    await tester.pump();
    expect(find.text('New Friend'), findsOneWidget);

    client.requests.first.completer.completeError(StateError('old failed'));
    await tester.pump();

    expect(find.text('New Friend'), findsOneWidget);
    expect(find.text('Search unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
