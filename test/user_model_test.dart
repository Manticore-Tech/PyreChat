import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/user.dart';

void main() {
  test('user parsing accepts snake_case display name', () {
    final user = PyreUser.fromJson({
      'id': 'u1',
      'username': 'max',
      'display_name': 'Max',
    });

    expect(user.id, 'u1');
    expect(user.username, 'max');
    expect(user.displayName, 'Max');
  });

  test('user parsing accepts Bitmoji-compatible avatar URL aliases', () {
    final user = PyreUser.fromJson({
      'id': 'u-avatar',
      'username': 'max',
      'displayName': 'Max',
      'bitmojiAvatar': 'https://example.invalid/avatar.png',
    });

    expect(user.avatarUrl, 'https://example.invalid/avatar.png');
  });

  test('empty display name falls back to username', () {
    final user = PyreUser.fromJson({
      'id': 'u2',
      'username': 'phoenix',
      'displayName': '   ',
    });

    expect(user.displayName, 'phoenix');
  });
}
