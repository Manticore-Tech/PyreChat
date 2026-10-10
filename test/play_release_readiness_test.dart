import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Google Play release readiness', () {
    test('canonical Android identity and version stay aligned', () {
      final pubspec = _read('pubspec.yaml');
      final gradle = _read('android/app/build.gradle.kts');
      final listing = _read('docs/GOOGLE_PLAY_LISTING_PACKAGE.md');
      final controlSheet = _read('docs/STORE_RELEASE.md');

      expect(pubspec, contains('version: 1.0.11+13'));
      expect(gradle, contains('applicationId = "dev.pyrearms.pyrechat_flutter"'));
      expect(gradle, contains('targetSdk = 36'));
      expect(listing, contains('Target package: `dev.pyrearms.pyrechat_flutter`'));
      expect(listing, contains('Target release: `1.0.11+13`'));
      expect(listing, isNot(contains('dev.pyrearms.chat')));
      expect(controlSheet,
          contains('Android package | `dev.pyrearms.pyrechat_flutter`'));
      expect(controlSheet,
          contains('Standalone RCS Worker `pyresocial-messaging`'));
      expect(
        controlSheet,
        isNot(contains('production `/api/app` still')),
      );
    });

    test('Play release documents stay aligned to the pubspec candidate', () {
      final pubspec = _read('pubspec.yaml');
      final listing = _read('docs/GOOGLE_PLAY_LISTING_PACKAGE.md');
      final controlSheet = _read('docs/STORE_RELEASE.md');
      final dataSafety = _read('docs/GOOGLE_PLAY_DATA_SAFETY.md');
      final provenance = _read('store/google-play/PROVENANCE.md');
      final versionMatch = RegExp(
        r'^version:\s*([^\s]+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(versionMatch, isNotNull);
      final releaseVersion = versionMatch!.group(1)!;
      final versionParts = releaseVersion.split('+');
      expect(versionParts, hasLength(2));
      expect(int.parse(versionParts[1]), greaterThan(3));
      expect(listing, contains('Target release: `$releaseVersion`'));
      expect(controlSheet, contains('Flutter release candidate | `$releaseVersion`'));
      expect(dataSafety, contains('Release: `$releaseVersion`'));
      expect(provenance, contains('Target release: `$releaseVersion`'));
    });

    test('release builds require Firebase and stable CI signing', () {
      final gradle = _read('android/app/build.gradle.kts');
      final workflow = _read('.github/workflows/mobile-alpha.yml');

      expect(gradle, contains('releaseBuildRequested && !googleServicesFile.exists()'));
      expect(gradle, contains('ANDROID_KEYSTORE_PATH'));
      expect(gradle, contains('ANDROID_KEYSTORE_PASSWORD'));
      expect(gradle, contains('ANDROID_KEY_ALIAS'));
      expect(gradle, contains('ANDROID_KEY_PASSWORD'));

      expect(workflow, contains('Configure stable Android alpha signing'));
      expect(workflow, contains('ANDROID_KEYSTORE_BASE64'));
      expect(workflow, contains('flutter build appbundle --release --no-pub'));
      expect(workflow, contains('build/app/outputs/bundle/release/app-release.aab'));
      expect(workflow, contains('FIREBASE_ANDROID_GOOGLE_SERVICES_JSON'));
    });

    test('Google Play release bundles cannot silently use debug signing', () {
      final gradle = _read('android/app/build.gradle.kts');

      expect(gradle, contains('val playReleaseBundleRequested'));
      expect(
        gradle,
        contains('if (playReleaseBundleRequested && !hasAlphaSigning)'),
      );
      expect(
        gradle,
        contains('Google Play release bundles require stable Android signing.'),
      );
      expect(
        gradle,
        contains('release AABs are guarded above and require stable signing'),
      );
    });

    test('Android permission surface stays store-release narrow', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      for (final requiredPermission in <String>[
        'android.permission.INTERNET',
        'android.permission.CAMERA',
        'android.permission.RECORD_AUDIO',
        'android.permission.POST_NOTIFICATIONS',
      ]) {
        expect(manifest, contains(requiredPermission));
      }

      for (final forbiddenPermission in <String>[
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.ACCESS_NOTIFICATION_POLICY',
        'android.permission.QUERY_ALL_PACKAGES',
        'android.permission.MANAGE_EXTERNAL_STORAGE',
        'android.permission.READ_CONTACTS',
        'android.permission.READ_SMS',
      ]) {
        expect(manifest, isNot(contains(forbiddenPermission)));
      }
    });
  });
}
