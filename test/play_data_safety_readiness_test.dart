import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Google Play Data safety readiness', () {
    test('draft preserves current privacy and encryption truth', () {
      final draft = _read('docs/GOOGLE_PLAY_DATA_SAFETY.md');

      expect(draft, contains('dev.pyrearms.pyrechat_flutter'));
      expect(draft, contains('New RCS text messages are **not end-to-end encrypted**'));
      expect(draft, contains('The separate Cloudflare Worker'));
      expect(draft, contains('Legacy PyreChat D1/R2 account/media data have **not been purged**'));
      expect(draft, contains('account/delete'));
      expect(
        draft,
        contains(
          'support.google.com/googleplay/android-developer/answer/10144311',
        ),
      );
    });

    test('draft does not overstate final third-party sharing classification', () {
      final draft = _read('docs/GOOGLE_PLAY_DATA_SAFETY.md');

      expect(draft, contains('Do not lock the Play Console "shared" answer'));
      expect(draft, contains('Firebase Cloud Messaging'));
      expect(draft, contains('Cloudflare'));
      expect(draft, contains('Google ML Kit'));
      expect(draft, contains('Camera Kit'));
      expect(draft, contains('exact submission AAB'));
    });

    test('declared permission boundary matches canonical Android manifest', () {
      final draft = _read('docs/GOOGLE_PLAY_DATA_SAFETY.md');
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      for (final permission in <String>[
        'android.permission.INTERNET',
        'android.permission.CAMERA',
        'android.permission.RECORD_AUDIO',
        'android.permission.POST_NOTIFICATIONS',
      ]) {
        expect(manifest, contains(permission));
      }

      for (final permission in <String>[
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.READ_CONTACTS',
        'android.permission.READ_SMS',
        'android.permission.READ_CALL_LOG',
        'android.permission.MANAGE_EXTERNAL_STORAGE',
        'android.permission.QUERY_ALL_PACKAGES',
      ]) {
        expect(manifest, isNot(contains(permission)));
      }

      expect(draft, contains('does not request location, contacts, SMS/call logs'));
    });

    test('release workflow keeps Camera Kit opt-in for the Play candidate', () {
      final workflow = _read('.github/workflows/mobile-alpha.yml');

      expect(workflow, contains('enable_camera_kit'));
      expect(workflow, contains('default: false'));
      expect(
        workflow,
        contains('Camera Kit internal evaluation disabled; building native fallback camera only.'),
      );
      expect(workflow, contains('flutter build appbundle --release --no-pub'));
    });
  });
}
