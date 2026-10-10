import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_mls.dart';
import 'package:pyrechat_flutter/services/secure_blob_store.dart';

class _MemorySecureBlobStore implements SecureBlobStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<bool> write(String name, String value) async {
    values[name] = value;
    return true;
  }

  @override
  Future<void> delete(String name) async {
    values.remove(name);
  }
}

void main() {
  test('MLS provisioning creates stable device identity and key packages', () async {
    final temp = await Directory.systemTemp.createTemp('pyrechat_mls_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final store = _MemorySecureBlobStore();
    final provisioner = PyreMlsProvisioner(
      secureStore: store,
      databasePathFor: (_, deviceId) async => '${temp.path}/$deviceId.db',
    );

    final first = await provisioner.prepareRegistration(
      userId: 'user-test-123',
      keyPackageCount: 2,
    );

    expect(first, isNotNull);
    expect(first!.deviceId, matches(RegExp(r'^[A-Za-z0-9_-]{16,160}$')));
    expect(base64Decode(first.signerPublicKey), isNotEmpty);
    expect(first.keyPackages, hasLength(2));
    for (final package in first.keyPackages) {
      expect(base64Decode(package), isNotEmpty);
    }

    final second = await provisioner.prepareRegistration(
      userId: 'user-test-123',
      keyPackageCount: 1,
    );

    expect(second, isNotNull);
    expect(second!.deviceId, first.deviceId);
    expect(second.signerPublicKey, first.signerPublicKey);
    expect(second.keyPackages, hasLength(1));
    expect(base64Decode(second.keyPackages.single), isNotEmpty);
  });
}
