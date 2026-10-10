import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';

class _SlowFriendsClient extends PyreClient {
  final friendsLoad = Completer<FriendAddsBundle>();

  @override
  Future<FriendAddsBundle> friendAdds() => friendsLoad.future;

  @override
  Future<List<PyreFriend>> searchUsers(String query) async {
    if (query != 'ember') return const [];
    return const [
      PyreFriend(id: 'friend-1', username: 'ember', displayName: 'Ember Friend'),
    ];
  }
}

void main() {
  testWidgets('username search works while friend requests are still loading',
      (tester) async {
    final client = _SlowFriendsClient();
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: client)),
    );

    await tester.enterText(find.byType(TextField), 'ember');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // A stalled friend-request request must not hide completed search results.
    expect(client.friendsLoad.isCompleted, isFalse);
    expect(find.text('Ember Friend'), findsOneWidget);
    expect(find.text('@ember'), findsOneWidget);
    expect(tester.takeException(), isNull);

    client.friendsLoad.complete(const FriendAddsBundle(
      incoming: [],
      sent: [],
      hidden: [],
      deleted: [],
      suggestions: [],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ember Friend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
