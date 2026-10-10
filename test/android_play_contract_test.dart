import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Play release contract stays aligned with store declarations', () {
    final gradle =
        File('android/app/build.gradle.kts').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      gradle,
      contains('applicationId = "dev.pyrearms.pyrechat_flutter"'),
    );
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('versionCode = flutter.versionCode'));
    expect(gradle, contains('versionName = flutter.versionName'));

    expect(
      manifest,
      contains('android.permission.POST_NOTIFICATIONS'),
    );
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    // A push wake must not expose a directly invokable Android service.
    expect(
      RegExp(
        r'<service\s+android:name="\.PyreFirebaseMessagingService"\s+android:exported="false"',
      ).hasMatch(manifest),
      isTrue,
      reason: 'Firebase wakes must enter through the private messaging service.',
    );
    // The exported JobScheduler service must require the system-only bind
    // permission; otherwise another installed app could trigger delivery work.
    expect(
      RegExp(
        r'<service\s+android:name="\.PyreRcsDeliveryJobService"\s+android:permission="android\.permission\.BIND_JOB_SERVICE"\s+android:exported="true"',
      ).hasMatch(manifest),
      isTrue,
      reason: 'Background delivery jobs must be protected by BIND_JOB_SERVICE.',
    );
    for (final permission in const [
      'android.permission.READ_SMS',
      'android.permission.RECEIVE_SMS',
      'android.permission.READ_CONTACTS',
      'android.permission.QUERY_ALL_PACKAGES',
      'android.permission.MANAGE_EXTERNAL_STORAGE',
    ]) {
      expect(manifest, isNot(contains(permission)),
          reason: 'Play release must not request $permission.');
    }

    expect(manifest, isNot(contains('android.permission.ACCESS_FINE_LOCATION')));
    expect(
      manifest,
      isNot(contains('android.permission.ACCESS_COARSE_LOCATION')),
    );
    expect(
      manifest,
      isNot(contains('android.permission.ACCESS_NOTIFICATION_POLICY')),
    );
  });

  test('Play bundle release fails closed without release credentials', () {
    final gradle =
        File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('val playReleaseBundleRequested ='));
    expect(
      gradle,
      contains('if (playReleaseBundleRequested && !hasAlphaSigning)'),
    );
    expect(
      gradle,
      contains('Google Play release bundles require stable Android signing.'),
    );

    for (final environmentName in const [
      'ANDROID_KEYSTORE_PATH',
      'ANDROID_KEYSTORE_PASSWORD',
      'ANDROID_KEY_ALIAS',
      'ANDROID_KEY_PASSWORD',
    ]) {
      expect(gradle, contains(environmentName));
    }

    expect(
      gradle,
      contains('if (releaseBuildRequested && !googleServicesFile.exists())'),
    );
    expect(
      gradle,
      contains(
        'Release builds require android/app/google-services.json so Firebase Cloud Messaging is enabled.',
      ),
    );
    expect(
      gradle,
      contains(
        'signingConfig = if (hasAlphaSigning) signingConfigs.getByName("alpha")',
      ),
    );
  });
}
