import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/screens/app_shell_screen.dart';
import 'package:pyrechat_flutter/screens/chats/chat_thread_screen.dart';

void main() {
  test('new web devices retry automatic key enrollment with bounded backoff', () {
    expect(
      [for (var attempt = 0; attempt < 9; attempt++)
        encryptionRegistrationBackoffSeconds(attempt)],
      [2, 4, 8, 15, 30, 60, 60, 60, 60],
    );
  });

  test('web-only peer has a useful next step without plaintext fallback', () {
    expect(
      privateSetupNotice(
        'A conversation member needs to open Pyre Social in a browser or app',
      ),
      contains('open or refresh Pyre Social'),
    );
    expect(
      privateSetupNotice('Waiting for peer encryption setup'),
      contains('Your message stays queued'),
    );
  });

  test('missing existing-group welcome is explicitly distinguished', () {
    final notice = privateSetupNotice(
      'This device is waiting for its encrypted conversation invite',
    );
    expect(notice, contains('not joined the existing encrypted chat'));
    expect(notice, isNot(contains('retry automatically')));
  });

  test('browser missing secure storage is not shown as recipient offline', () {
    final notice = privateSetupNotice(
      'Encrypted messaging is unavailable on this device',
    );
    expect(notice, contains('site storage enabled'));
  });
}
