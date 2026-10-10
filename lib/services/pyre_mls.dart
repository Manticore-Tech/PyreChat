import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:openmls/openmls.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/secure_blob_store.dart';

class PyreMlsDeviceBundle {
  const PyreMlsDeviceBundle({
    required this.deviceId,
    required this.signerPublicKey,
    required this.keyPackages,
  });

  final String deviceId;
  final String signerPublicKey;
  final List<String> keyPackages;
}

class PyreEncryptedMessageEnvelope {
  const PyreEncryptedMessageEnvelope._({
    required this.version,
    required this.protocol,
    required this.kind,
    required this.clientId,
    required this.ciphertext,
  });

  static const currentVersion = 1;
  static const mlsProtocol = 'mls10';
  static const mlsKind = 'mls';
  static final RegExp clientIdPattern = RegExp(r'^[A-Za-z0-9_-]{20,160}$');

  final int version;
  final String protocol;
  final String kind;
  final String clientId;
  final String ciphertext;

  factory PyreEncryptedMessageEnvelope.mls({
    required String clientId,
    required String ciphertext,
  }) {
    if (!clientIdPattern.hasMatch(clientId)) {
      throw ArgumentError.value(
        clientId,
        'clientId',
        'invalid encrypted message id',
      );
    }
    try {
      if (base64Decode(ciphertext).isEmpty) {
        throw const FormatException('empty ciphertext');
      }
    } on FormatException {
      throw ArgumentError.value(
        ciphertext,
        'ciphertext',
        'must be base64 MLS ciphertext',
      );
    }
    return PyreEncryptedMessageEnvelope._(
      version: currentVersion,
      protocol: mlsProtocol,
      kind: mlsKind,
      clientId: clientId,
      ciphertext: ciphertext,
    );
  }

  static PyreEncryptedMessageEnvelope? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != currentVersion ||
          decoded['protocol'] != mlsProtocol ||
          decoded['kind'] != mlsKind ||
          decoded['clientId'] is! String ||
          decoded['ciphertext'] is! String) {
        return null;
      }
      return PyreEncryptedMessageEnvelope.mls(
        clientId: decoded['clientId'] as String,
        ciphertext: decoded['ciphertext'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'v': version,
        'protocol': protocol,
        'kind': kind,
        'clientId': clientId,
        'ciphertext': ciphertext,
      };
}

abstract interface class PyrePrivateConversationCodec {
  String get chatId;
  String get userId;
  String get deviceId;

  String newClientMessageId();

  Future<String> encryptForSend({
    required String messageId,
    required String plaintext,
  });

  Future<String?> decryptMessage({
    required String messageId,
    required String ciphertext,
    required bool sentByMe,
  });

  Future<void> cachePlaintext(String messageId, String plaintext);

  Future<({bool allReady, bool legacyPlaintextPurged})> markLegacyReady(
    PyreClient client,
  );

  Future<void> close();
}

abstract interface class PyreMlsConversationManager {
  Future<PyreMlsOpenResult> openConversation({
    required PyreClient client,
    required String userId,
    required String chatId,
  });
}

class PyreMlsSyncResult {
  const PyreMlsSyncResult({
    required this.supported,
    required this.registered,
    required this.availableKeyPackages,
    required this.uploadedKeyPackages,
    this.deviceId,
  });

  const PyreMlsSyncResult.unsupported()
      : supported = false,
        registered = false,
        availableKeyPackages = 0,
        uploadedKeyPackages = 0,
        deviceId = null;

  final bool supported;
  final bool registered;
  final int availableKeyPackages;
  final int uploadedKeyPackages;
  final String? deviceId;
}

/// Client-side MLS device provisioning for PyreChat.
///
/// This is deliberately separate from message sending. It establishes stable
/// per-device MLS identity/key-package material without silently turning on
/// encrypted conversation transport before the full bootstrap/join/message
/// round trip is verified.
///
/// Production storage fails closed: the default [SecureBlobStore] currently
/// supports Android only and never falls back to plaintext preferences.
class PyreMlsOpenResult {
  const PyreMlsOpenResult({
    required this.supported,
    this.conversation,
    this.waitingReason,
  });

  const PyreMlsOpenResult.unsupported()
      : supported = false,
        conversation = null,
        waitingReason = 'Encrypted messaging is unavailable on this device';

  final bool supported;
  final PyrePrivateConversationCodec? conversation;
  final String? waitingReason;

  bool get ready => conversation != null;
}

class PyreMlsConversation implements PyrePrivateConversationCodec {
  PyreMlsConversation._({
    required this.chatId,
    required this.userId,
    required this.deviceId,
    required Uint8List groupId,
    required MlsEngine engine,
    required Uint8List signerBytes,
    required SecureBlobStore secureStore,
  })  : _groupId = groupId,
        _engine = engine,
        _signerBytes = signerBytes,
        _secureStore = secureStore;

  @override
  final String chatId;
  @override
  final String userId;
  @override
  final String deviceId;
  final Uint8List _groupId;
  final MlsEngine _engine;
  final Uint8List _signerBytes;
  final SecureBlobStore _secureStore;
  bool _closed = false;

  @override
  String newClientMessageId() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(24, (_) => random.nextInt(256), growable: false),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Future<String> encryptForSend({
    required String messageId,
    required String plaintext,
  }) async {
    _ensureOpen();
    if (plaintext.trim().isEmpty) {
      throw ArgumentError.value(plaintext, 'plaintext', 'must not be empty');
    }

    final pendingKey = _cacheName(_outgoingName(messageId));
    final pendingPacket = await _secureStore.read(pendingKey);
    if (pendingPacket != null && pendingPacket.isNotEmpty) return pendingPacket;

    await cachePlaintext(messageId, plaintext);
    final encrypted = await _engine.createMessage(
      groupIdBytes: _groupId,
      signerBytes: _signerBytes,
      message: utf8.encode(plaintext),
    );
    final packet = base64Encode(encrypted.ciphertext);
    // Encryption advances MLS state. Persist the exact packet before HTTP so
    // retries after an ambiguous response reuse the original ciphertext.
    if (!await _secureStore.write(pendingKey, packet)) {
      throw StateError('Could not preserve encrypted outgoing message');
    }
    return packet;
  }

  @override
  Future<String?> decryptMessage({
    required String messageId,
    required String ciphertext,
    required bool sentByMe,
  }) async {
    _ensureOpen();
    final cached = await cachedPlaintext(messageId);
    if (cached != null) return cached;
    if (sentByMe) return null;

    final bytes = base64Decode(ciphertext);
    final processed = await _engine.processMessage(
      groupIdBytes: _groupId,
      messageBytes: bytes,
    );
    final application = processed.applicationMessage;
    if (application == null) return null;

    final plaintext = utf8.decode(application);
    await cachePlaintext(messageId, plaintext);
    return plaintext;
  }

  @override
  Future<void> cachePlaintext(String messageId, String plaintext) async {
    if (messageId.isEmpty || plaintext.isEmpty) return;
    final ok = await _secureStore.write(_cacheName(messageId), plaintext);
    if (!ok) {
      throw StateError('Could not preserve private message text securely');
    }
  }

  Future<String?> cachedPlaintext(String messageId) {
    if (messageId.isEmpty) return Future.value(null);
    return _secureStore.read(_cacheName(messageId));
  }

  @override
  Future<({bool allReady, bool legacyPlaintextPurged})> markLegacyReady(
    PyreClient client,
  ) {
    _ensureOpen();
    return client.markE2eeLegacyReady(
      chatId: chatId,
      deviceId: deviceId,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _engine.close();
    } finally {
      _signerBytes.fillRange(0, _signerBytes.length, 0);
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Encrypted conversation is closed');
  }

  static String _cacheName(String messageId) => 'pyre_mls_msg_v1_$messageId';
  static String _outgoingName(String messageId) => 'pyre_mls_out_v1_$messageId';
}

class PyreMlsProvisioner implements PyreMlsConversationManager {
  PyreMlsProvisioner({
    SecureBlobStore? secureStore,
    Future<String> Function(String userId, String deviceId)? databasePathFor,
    Uint8List Function(int length)? randomBytes,
  })  : _secureStore = secureStore ?? const PlatformSecureBlobStore(),
        _databasePathFor = databasePathFor ?? _defaultDatabasePath,
        _randomBytes = randomBytes ?? _secureRandomBytes;

  static const _identityVersion = 1;
  static const _targetKeyPackages = 8;
  static const _minimumKeyPackages = 4;
  static const _ciphersuite =
      MlsCiphersuite.mls128DhkemX25519Aes128GcmSha256Ed25519;

  static Future<void>? _openMlsInit;

  final SecureBlobStore _secureStore;
  final Future<String> Function(String userId, String deviceId)
      _databasePathFor;
  final Uint8List Function(int length) _randomBytes;

  Future<void> deleteLocalIdentity(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty || !await _secureStore.isSupported) return;

    final storageName = _identityStorageName(cleanUserId);
    final stored = await _secureStore.read(storageName);
    final identity = stored == null ? null : _parseIdentity(stored);

    if (identity != null) {
      final databasePath = await _databasePathFor(
        cleanUserId,
        identity.deviceId,
      );
      for (final suffix in const ['', '-wal', '-shm']) {
        try {
          final file = File('$databasePath$suffix');
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Local account cleanup is best-effort; always remove the key below.
        }
      }
    }

    await _secureStore.delete(storageName);
  }

  Future<PyreMlsDeviceBundle?> prepareRegistration({
    required String userId,
    int keyPackageCount = _targetKeyPackages,
  }) async {
    if (userId.trim().isEmpty || keyPackageCount < 0 || keyPackageCount > 16) {
      throw ArgumentError('Invalid MLS registration request');
    }
    if (!await _secureStore.isSupported) return null;

    final identity = await _loadOrCreateIdentity(userId);
    final packages = keyPackageCount == 0
        ? const <String>[]
        : await _createKeyPackages(
            userId: userId,
            identity: identity,
            count: keyPackageCount,
          );

    return PyreMlsDeviceBundle(
      deviceId: identity.deviceId,
      signerPublicKey: identity.signerPublicKey,
      keyPackages: packages,
    );
  }

  Future<PyreMlsSyncResult> syncRegistration({
    required PyreClient client,
    required String userId,
  }) async {
    if (!await _secureStore.isSupported) {
      return const PyreMlsSyncResult.unsupported();
    }

    final identity = await _loadOrCreateIdentity(userId);
    final status = await client.e2eeDeviceStatus(identity.deviceId);

    if (status.registered &&
        status.signerPublicKey != null &&
        status.signerPublicKey != identity.signerPublicKey) {
      throw PyreApiException(
        'Encryption device identity does not match this installation',
        409,
      );
    }

    if (status.registered &&
        status.availableKeyPackages >= _minimumKeyPackages) {
      return PyreMlsSyncResult(
        supported: true,
        registered: true,
        availableKeyPackages: status.availableKeyPackages,
        uploadedKeyPackages: 0,
        deviceId: identity.deviceId,
      );
    }

    final missing = (_targetKeyPackages - status.availableKeyPackages)
        .clamp(0, _targetKeyPackages)
        .toInt();
    final packages = await _createKeyPackages(
      userId: userId,
      identity: identity,
      count: missing,
    );
    final available = await client.registerE2eeDevice(
      deviceId: identity.deviceId,
      signerPublicKey: identity.signerPublicKey,
      keyPackages: packages,
    );

    return PyreMlsSyncResult(
      supported: true,
      registered: true,
      availableKeyPackages: available,
      uploadedKeyPackages: packages.length,
      deviceId: identity.deviceId,
    );
  }

  Future<_PyreMlsIdentity> _loadOrCreateIdentity(String userId) async {
    await _ensureOpenMls();
    final storageName = _identityStorageName(userId);
    final stored = await _secureStore.read(storageName);
    if (stored != null) {
      final parsed = _parseIdentity(stored);
      if (parsed != null) return parsed;
      await _secureStore.delete(storageName);
    }

    final deviceId = base64UrlEncode(_randomBytes(24)).replaceAll('=', '');
    final dbKey = _randomBytes(32);
    final keyPair = MlsSignatureKeyPair.generate(ciphersuite: _ciphersuite);
    final privateKey = keyPair.privateKey();
    final publicKey = keyPair.publicKey();
    final signer = serializeSigner(
      ciphersuite: _ciphersuite,
      privateKey: privateKey,
      publicKey: publicKey,
    );

    try {
      final identity = _PyreMlsIdentity(
        deviceId: deviceId,
        databaseKey: base64Encode(dbKey),
        signer: base64Encode(signer),
        signerPublicKey: base64Encode(publicKey),
      );
      final saved = await _secureStore.write(
        storageName,
        jsonEncode(identity.toJson()),
      );
      if (!saved) {
        throw StateError('Could not persist MLS device identity securely');
      }
      return identity;
    } finally {
      dbKey.fillRange(0, dbKey.length, 0);
      privateKey.fillRange(0, privateKey.length, 0);
      signer.fillRange(0, signer.length, 0);
    }
  }

  Future<List<String>> _createKeyPackages({
    required String userId,
    required _PyreMlsIdentity identity,
    required int count,
  }) async {
    if (count <= 0) return const [];

    await _ensureOpenMls();
    final databaseKey = Uint8List.fromList(base64Decode(identity.databaseKey));
    final signerBytes = Uint8List.fromList(base64Decode(identity.signer));
    final signerPublicKey =
        Uint8List.fromList(base64Decode(identity.signerPublicKey));
    final credentialIdentity =
        Uint8List.fromList(utf8.encode('$userId:${identity.deviceId}'));
    final databasePath = await _databasePathFor(userId, identity.deviceId);

    MlsEngine? engine;
    try {
      engine = await MlsEngine.create(
        dbPath: databasePath,
        encryptionKey: databaseKey,
      );

      final capabilities = MlsCapabilities(
        versions: Uint16List.fromList(const [1]),
        ciphersuites: Uint16List.fromList(const [0x0001]),
        extensions: Uint16List(0),
        proposals: Uint16List(0),
        credentials: Uint16List.fromList(const [1]),
      );
      final options = KeyPackageOptions(
        lastResort: false,
        capabilities: capabilities,
      );

      final packages = <String>[];
      for (var i = 0; i < count; i++) {
        final result = await engine.createKeyPackageWithOptions(
          ciphersuite: _ciphersuite,
          signerBytes: signerBytes,
          credentialIdentity: credentialIdentity,
          signerPublicKey: signerPublicKey,
          options: options,
        );
        packages.add(base64Encode(result.keyPackageBytes));
      }
      return List.unmodifiable(packages);
    } finally {
      await engine?.close();
      databaseKey.fillRange(0, databaseKey.length, 0);
      signerBytes.fillRange(0, signerBytes.length, 0);
    }
  }

  @override
  Future<PyreMlsOpenResult> openConversation({
    required PyreClient client,
    required String userId,
    required String chatId,
  }) async {
    if (userId.trim().isEmpty || chatId.trim().isEmpty) {
      throw ArgumentError('Encrypted conversation identity must not be empty');
    }
    if (!await _secureStore.isSupported) {
      return const PyreMlsOpenResult.unsupported();
    }

    final registration = await syncRegistration(
      client: client,
      userId: userId,
    );
    if (!registration.registered || registration.deviceId == null) {
      return const PyreMlsOpenResult.unsupported();
    }

    final identity = await _loadOrCreateIdentity(userId);
    return _openConversationWithIdentity(
      client: client,
      userId: userId,
      chatId: chatId,
      identity: identity,
    );
  }

  Future<PyreMlsOpenResult> _openConversationWithIdentity({
    required PyreClient client,
    required String userId,
    required String chatId,
    required _PyreMlsIdentity identity,
  }) async {
    await _ensureOpenMls();
    final engine = await _openEngine(userId, identity);
    try {
      final state = await client.e2eeChatState(
        chatId: chatId,
        deviceId: identity.deviceId,
      );

      if (state.enabled) {
        return await _joinOrOpenExisting(
          client: client,
          userId: userId,
          chatId: chatId,
          identity: identity,
          engine: engine,
          groupIdBase64: state.groupId,
          welcomeBase64: state.welcome,
        );
      }

      final material = await client.e2eeBootstrapMaterial(
        chatId: chatId,
        deviceId: identity.deviceId,
      );

      if (material.existing) {
        await engine.close();
        return await _openConversationWithIdentity(
          client: client,
          userId: userId,
          chatId: chatId,
          identity: identity,
        );
      }

      if (material.members.isEmpty ||
          material.attemptId == null ||
          material.attemptId!.isEmpty) {
        await engine.close();
        return const PyreMlsOpenResult(
          supported: true,
          waitingReason:
              'Waiting for the other device to prepare encrypted messaging',
        );
      }

      final signerBytes = Uint8List.fromList(base64Decode(identity.signer));
      final signerPublicKey =
          Uint8List.fromList(base64Decode(identity.signerPublicKey));
      final config = MlsGroupConfig.defaultConfig(ciphersuite: _ciphersuite);
      final group = await engine.createGroup(
        config: config,
        signerBytes: signerBytes,
        credentialIdentity:
            utf8.encode('$userId:${identity.deviceId}'),
        signerPublicKey: signerPublicKey,
      );

      final add = await engine.addMembers(
        groupIdBytes: group.groupId,
        signerBytes: signerBytes,
        keyPackagesBytes: material.members
            .map((member) => Uint8List.fromList(base64Decode(member.keyPackage)))
            .toList(growable: false),
      );
      await engine.mergePendingCommit(groupIdBytes: group.groupId);

      final groupIdBase64 = base64Encode(group.groupId);
      final bootstrap = await client.bootstrapE2eeChat(
        chatId: chatId,
        deviceId: identity.deviceId,
        attemptId: material.attemptId!,
        groupId: groupIdBase64,
        welcome: base64Encode(add.welcome),
      );

      if (bootstrap.created || bootstrap.groupId == groupIdBase64) {
        return PyreMlsOpenResult(
          supported: true,
          conversation: PyreMlsConversation._(
            chatId: chatId,
            userId: userId,
            deviceId: identity.deviceId,
            groupId: Uint8List.fromList(group.groupId),
            engine: engine,
            signerBytes: signerBytes,
            secureStore: _secureStore,
          ),
        );
      }

      try {
        await engine.deleteGroup(groupIdBytes: group.groupId);
      } catch (_) {}
      signerBytes.fillRange(0, signerBytes.length, 0);
      await engine.close();
      return await _openConversationWithIdentity(
        client: client,
        userId: userId,
        chatId: chatId,
        identity: identity,
      );
    } on PyreApiException catch (error) {
      await engine.close();
      if (error.statusCode == 409) {
        return PyreMlsOpenResult(
          supported: true,
          waitingReason: error.message,
        );
      }
      rethrow;
    } catch (_) {
      await engine.close();
      rethrow;
    }
  }

  Future<PyreMlsOpenResult> _joinOrOpenExisting({
    required PyreClient client,
    required String userId,
    required String chatId,
    required _PyreMlsIdentity identity,
    required MlsEngine engine,
    required String? groupIdBase64,
    required String? welcomeBase64,
  }) async {
    if (groupIdBase64 == null || groupIdBase64.isEmpty) {
      await engine.close();
      throw StateError('Encrypted conversation is missing its MLS group id');
    }

    final groupId = Uint8List.fromList(base64Decode(groupIdBase64));
    var active = false;
    try {
      active = await engine.groupIsActive(groupIdBytes: groupId);
    } catch (_) {
      active = false;
    }

    final signerBytes = Uint8List.fromList(base64Decode(identity.signer));
    if (!active) {
      if (welcomeBase64 == null || welcomeBase64.isEmpty) {
        signerBytes.fillRange(0, signerBytes.length, 0);
        await engine.close();
        return const PyreMlsOpenResult(
          supported: true,
          waitingReason:
              'This device is waiting for its encrypted conversation invite',
        );
      }

      final config = MlsGroupConfig.defaultConfig(ciphersuite: _ciphersuite);
      final joined = await engine.joinGroupFromWelcome(
        config: config,
        welcomeBytes: base64Decode(welcomeBase64),
        signerBytes: signerBytes,
      );
      if (base64Encode(joined.groupId) != groupIdBase64) {
        signerBytes.fillRange(0, signerBytes.length, 0);
        await engine.close();
        throw StateError('Encrypted conversation group identity mismatch');
      }
      await client.consumeE2eeWelcome(
        chatId: chatId,
        deviceId: identity.deviceId,
      );
    }

    return PyreMlsOpenResult(
      supported: true,
      conversation: PyreMlsConversation._(
        chatId: chatId,
        userId: userId,
        deviceId: identity.deviceId,
        groupId: groupId,
        engine: engine,
        signerBytes: signerBytes,
        secureStore: _secureStore,
      ),
    );
  }

  Future<MlsEngine> _openEngine(
    String userId,
    _PyreMlsIdentity identity,
  ) async {
    final databaseKey = Uint8List.fromList(base64Decode(identity.databaseKey));
    try {
      return await MlsEngine.create(
        dbPath: await _databasePathFor(userId, identity.deviceId),
        encryptionKey: databaseKey,
      );
    } finally {
      databaseKey.fillRange(0, databaseKey.length, 0);
    }
  }

  _PyreMlsIdentity? _parseIdentity(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['v'] != _identityVersion) return null;
      final deviceId = decoded['deviceId'];
      final databaseKey = decoded['databaseKey'];
      final signer = decoded['signer'];
      final signerPublicKey = decoded['signerPublicKey'];
      if (deviceId is! String ||
          databaseKey is! String ||
          signer is! String ||
          signerPublicKey is! String) {
        return null;
      }
      if (!RegExp(r'^[A-Za-z0-9_-]{16,160}$').hasMatch(deviceId)) return null;
      if (base64Decode(databaseKey).length != 32) return null;
      if (base64Decode(signer).isEmpty || base64Decode(signerPublicKey).isEmpty) {
        return null;
      }
      return _PyreMlsIdentity(
        deviceId: deviceId,
        databaseKey: databaseKey,
        signer: signer,
        signerPublicKey: signerPublicKey,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ensureOpenMls() {
    return _openMlsInit ??= Openmls.init();
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256), growable: false),
    );
  }

  static String _identityStorageName(String userId) {
    final scope =
        base64UrlEncode(utf8.encode(userId.trim())).replaceAll('=', '');
    return 'pyre_mls_identity_v1_$scope';
  }

  static Future<String> _defaultDatabasePath(
    String userId,
    String deviceId,
  ) async {
    final scope =
        base64UrlEncode(utf8.encode(userId.trim())).replaceAll('=', '');
    // On web OpenMLS uses this as an IndexedDB name (encrypted with WebCrypto).
    // path_provider is native-only; never access it in a browser.
    if (kIsWeb) return 'pyre_mls_v1_${scope}_$deviceId.db';
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/pyre_mls_v1_${scope}_$deviceId.db';
  }
}

class _PyreMlsIdentity {
  const _PyreMlsIdentity({
    required this.deviceId,
    required this.databaseKey,
    required this.signer,
    required this.signerPublicKey,
  });

  final String deviceId;
  final String databaseKey;
  final String signer;
  final String signerPublicKey;

  Map<String, dynamic> toJson() => {
        'v': PyreMlsProvisioner._identityVersion,
        'deviceId': deviceId,
        'databaseKey': databaseKey,
        'signer': signer,
        'signerPublicKey': signerPublicKey,
      };
}
