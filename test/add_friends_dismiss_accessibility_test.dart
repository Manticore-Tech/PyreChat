import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';

class _FriendsClient extends PyreClient {
  String? dismissedKind;
  String? removedId;

  @override
  Future<FriendAddsBundle> friendAdds() async => const FriendAddsBundle(
        incoming: [
          PyreFriend(id: 'f1', username: 'avery', displayName: 'Avery'),
        ],
        sent: [
          PyreFriend(id: 'f2', username: 'blair', displayName: 'Blair'),
        ],
        hidden: [],
        deleted: [],
        suggestions: [],
      );

  @override
  Future<void> dismissFriend({
    required String userId,
    required String kind,
  }) async {
    dismissedKind = '$userId:$kind';
  }

  @override
  Future<void> removeFriend(String userId) async {
    removedId = userId;
  }
}

void main() {
  testWidgets('incoming dismiss names its effect and ignores only that request',
      (tester) async {
    final client = _FriendsClient();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    final ignore = find.byTooltip('Ignore friend request from Avery');
    expect(ignore, findsOneWidget);
    await tester.tap(ignore);
    await tester.pumpAndSettle();
    expect(client.dismissedKind, 'f1:deleted');
    semantics.dispose();
  });

  testWidgets('sent dismiss clearly identifies request cancellation',
      (tester) async {
    final client = _FriendsClient();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: AddFriendsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sent requests'));
    await tester.pumpAndSettle();

    final cancel = find.byTooltip('Cancel friend request to Blair');
    expect(cancel, findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(client.removedId, 'f2');
    semantics.dispose();
  });
}
