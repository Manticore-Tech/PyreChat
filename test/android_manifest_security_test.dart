import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest disables backup and cleartext traffic', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });
}
