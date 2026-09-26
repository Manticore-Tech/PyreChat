import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';

void main() {
  test('direct chat uses the other member for title and camera target', () {
    final chat = ChatPreview.fromApi(
      {
        'id': 'chat-1',
        'is_group': 0,
        'members': [
          {'id': 'me', 'display_name': 'My Account', 'username': 'me'},
          {
            'user_id': 'friend-1',
            'display_name': 'Palm Beach Pete',
            'username': 'pete',
          },
        ],
      },
      meId: 'me',
    );

    expect(chat.title, 'Palm Beach Pete');
    expect(chat.memberIds, containsAll(<String>['me', 'friend-1']));
    expect(chat.recipientIdsFor('me'), <String>['friend-1']);
  });

  test('member id parsing tolerates alternate api key spellings and duplicates', () {
    final chat = ChatPreview.fromApi(
      {
        'id': 'group-1',
        'is_group': 1,
        'name': 'Group',
        'members': [
          {'id': 'a'},
          {'userId': 'b'},
          {'user_id': 'b'},
          {'username': 'missing-id'},
        ],
      },
      meId: 'a',
    );

    expect(chat.memberIds, <String>['a', 'b']);
    expect(chat.recipientIdsFor('a'), <String>['b']);
  });

  test('direct title accepts camelCase displayName from compatible backends', () {
    final chat = ChatPreview.fromApi(
      {
        'id': 'chat-2',
        'is_group': 0,
        'members': [
          {'id': 'me', 'displayName': 'Me', 'username': 'me'},
          {'id': 'friend-2', 'displayName': 'Friend Two', 'username': 'friend2'},
        ],
      },
      meId: 'me',
    );

    expect(chat.title, 'Friend Two');
  });
}
