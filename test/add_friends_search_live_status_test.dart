import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';

class _PendingSearchClient extends PyreClient {
  _PendingSearchClient(this.result);

  final Completer<List<PyreFriend>> result;

  @override
  Future<FriendAddsBundle> friendAdds() async => const FriendAddsBundle(
        incoming: [],
        sent: [],
        hidden: [],
        deleted: [],
        suggestions: [],
      );

  @override
  Future<List<PyreFriend>> searchUsers(String query) => result.future;
}

void main() {
  testWidgets('friend search announces loading and empty results',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final result = Completer<List<PyreFriend>>();
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: _PendingSearchClient(result))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'no_one');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Searching usernames'), findsOneWidget);

    result.complete(const []);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('No people match “no_one”.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('friend search failure announces error and keeps retry visible',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final result = Completer<List<PyreFriend>>();
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: _PendingSearchClient(result))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump(const Duration(milliseconds: 300));
    result.completeError(StateError('network unavailable'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Search unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
