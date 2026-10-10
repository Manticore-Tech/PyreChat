import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_mls.dart';
import 'package:pyrechat_flutter/services/secure_blob_store.dart';

class _MemorySecrets implements SecureBlobStore {
  final Map<String, String> saved = {};
  @override
  Future<bool> get isSupported async => true;
  @override
  Future<String?> read(String name) async => saved[name];
  @override
  Future<bool> write(String name, String value) async {
    saved[name] = value;
    return true;
  }
  @override
  Future<void> delete(String name) async => saved.remove(name);
}

class _TestDevice {
  _TestDevice(this.deviceId, this.signer, this.packages);
  final String deviceId;
  final String signer;
  final List<String> packages;
}

class _TestKeyServer {
  final devices = <String, _TestDevice>{};
  String? groupId;
  String? welcome;
  String? recipient;
  bool consumed = false;
}

class _TestClient extends PyreClient {
  _TestClient(this.user, this.server, this.other);
  final String user;
  final String other;
  final _TestKeyServer server;

  @override
  Future<({bool registered, int availableKeyPackages, String? signerPublicKey})>
      e2eeDeviceStatus(String deviceId) async {
    final device = server.devices[user];
    return (
      registered: device?.deviceId == deviceId,
      availableKeyPackages: device?.packages.length ?? 0,
      signerPublicKey: device?.signer,
    );
  }

  @override
  Future<int> registerE2eeDevice({
    required String deviceId,
    required String signerPublicKey,
    required List<String> keyPackages,
  }) async {
    final current = server.devices[user];
    if (current == null) {
      server.devices[user] = _TestDevice(deviceId, signerPublicKey, [...keyPackages]);
    } else {
      expect(deviceId, current.deviceId);
      expect(signerPublicKey, current.signer);
      current.packages.addAll(keyPackages);
    }
    return server.devices[user]!.packages.length;
  }

  @override
  Future<({bool enabled, String? groupId, String? protocol, String? createdAt, String? welcome})>
      e2eeChatState({required String chatId, required String deviceId}) async => (
    enabled: server.groupId != null,
    groupId: server.groupId,
    protocol: 'mls10',
    createdAt: null,
    welcome: server.recipient == user && !server.consumed ? server.welcome : null,
  );

  @override
  Future<({bool existing, String? groupId, String? attemptId,
    List<({String userId, String deviceId, String keyPackage})> members})>
      e2eeBootstrapMaterial({required String chatId, required String deviceId}) async {
    if (server.groupId != null) {
      return (existing: true, groupId: server.groupId, attemptId: null,
        members: <({String userId, String deviceId, String keyPackage})>[]);
    }
    final peer = server.devices[other];
    if (peer == null || peer.packages.isEmpty) {
      throw PyreApiException('Peer encryption device not yet registered', 409);
    }
    return (
      existing: false,
      groupId: null,
      attemptId: 'trial-1',
      members: [(userId: other, deviceId: peer.deviceId, keyPackage: peer.packages.first)],
    );
  }

  @override
  Future<({bool created, String groupId})> bootstrapE2eeChat({
    required String chatId,
    required String deviceId,
    required String attemptId,
    required String groupId,
    required String welcome,
  }) async {
    server.groupId = groupId;
    server.welcome = welcome;
    server.recipient = other;
    return (created: true, groupId: groupId);
  }

  @override
  Future<void> consumeE2eeWelcome({
    required String chatId,
    required String deviceId,
  }) async {
    server.consumed = true;
  }
}

void main() {
  test('two real MLS engines encrypt, join, decrypt and safely retry', () async {
    final folder = await Directory.systemTemp.createTemp('pyre-mls-roundtrip-');
    addTearDown(() async {
      if (await folder.exists()) await folder.delete(recursive: true);
    });
    final server = _TestKeyServer();
    final alice = _TestClient('alice', server, 'bob');
    final bob = _TestClient('bob', server, 'alice');
    final aliceKeys = PyreMlsProvisioner(
      secureStore: _MemorySecrets(),
      databasePathFor: (user, deviceId) async => '${folder.path}/${user}_$deviceId.db',
    );
    final bobKeys = PyreMlsProvisioner(
      secureStore: _MemorySecrets(),
      databasePathFor: (user, deviceId) async => '${folder.path}/${user}_$deviceId.db',
    );
    final beforePeer = await aliceKeys.openConversation(
      client: alice, userId: 'alice', chatId: 'direct-test',
    );
    expect(beforePeer.ready, false);
    expect(beforePeer.waitingReason, contains('Peer encryption device'));
    final peerRegistration = await bobKeys.syncRegistration(client: bob, userId: 'bob');
    expect(peerRegistration.registered, true);

    final initiated = await aliceKeys.openConversation(
      client: alice, userId: 'alice', chatId: 'direct-test',
    );
    expect(initiated.ready, true);
    final joined = await bobKeys.openConversation(
      client: bob, userId: 'bob', chatId: 'direct-test',
    );
    expect(joined.ready, true);
    final sender = initiated.conversation!;
    final receiver = joined.conversation!;
    try {
      const id = 'secure-message-id-000001';
      final packet = await sender.encryptForSend(
        messageId: id, plaintext: 'Private round trip works',
      );
      expect(packet, isNotEmpty);
      final replay = await sender.encryptForSend(
        messageId: id, plaintext: 'Private round trip works',
      );
      expect(replay, packet, reason: 'Ambiguous HTTP retry reuses exact ciphertext');
      final plaintext = await receiver.decryptMessage(
        messageId: id, ciphertext: packet, sentByMe: false,
      );
      expect(plaintext, 'Private round trip works');
    } finally {
      await sender.close();
      await receiver.close();
    }
  });
}
