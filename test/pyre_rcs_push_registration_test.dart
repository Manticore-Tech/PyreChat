// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pyrechat_flutter/services/pyre_rcs.dart';
import 'package:pyrechat_flutter/services/secure_blob_store.dart';

class _Keys implements SecureBlobStore {
  final records = <String, String>{};

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<String?> read(String name) async => records[name];

  @override
  Future<bool> write(String name, String value) async {
    records[name] = value;
    return true;
  }

  @override
  Future<void> delete(String name) async {
    records.remove(name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notifications = MethodChannel('dev.pyrearms.pyrechat/notifications');
  const secure = MethodChannel('dev.pyrearms.pyrechat/secure_session');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(secure, null);
  });

  test('Android binds current RCS address to FCM without exposing signing keys', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final keys = _Keys();
    final fcmToken = 'fcm:' + ('ABCdef0123_' * 15);
    var pushRegistrations = 0;
    var grantWrites = 0;
    String? handle;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      expect(call.method, 'getPushToken');
      return fcmToken;
    });
    messenger.setMockMethodCallHandler(secure, (call) async {
      expect(call.method, 'writeSecret');
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['name'], 'pyre_rcs_native_delivery_grant_v1');
      final grant = jsonDecode(args['value'] as String) as Map<String, dynamic>;
      expect(grant['handle'], handle);
      expect(grant['deviceId'], matches(RegExp(r'^[A-Za-z0-9_-]{16,80}$')));
      expect(grant['deliveryKey'], 'K' * 43);
      expect(grant['expiresAtMs'], greaterThan(DateTime.now().millisecondsSinceEpoch));
      expect(args['value'], isNot(contains('"seed"')));
      grantWrites++;
      return true;
    });
    final client = PyreRcsClient(
      accountScope: 'pyresocial-rcs-primary-v1',
      secrets: keys,
      httpClient: MockClient((request) async {
        if (request.url.path == '/v1/identity/challenge') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          handle = data['handle'] as String;
          return http.Response(jsonEncode({'nonce': 'N' * 43}), 200);
        }
        if (request.url.path == '/v1/identity/enroll') {
          return http.Response(jsonEncode({
            'token': handle! + '.' + ('A' * 43),
            'expiresAt': DateTime.now().toUtc()
                .add(const Duration(days: 7)).toIso8601String(),
          }), 201);
        }
        if (request.url.path == '/v1/rcs/push/status') {
          expect(request.url.queryParameters['deviceId'], isNotEmpty);
          expect(request.headers['authorization'],
              'Bearer ' + handle! + '.' + 'A' * 43);
          return http.Response(jsonEncode({
            'registered': true,
            'configured': true,
            'lastProviderResult': 'sent',
            'lastDeviceReceiptAt': null,
          }), 200);
        }
        if (request.url.path == '/v1/rcs/push/register') {
          pushRegistrations++;
          expect(request.headers['authorization'], 'Bearer ' + handle! + '.' + 'A' * 43);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['platform'], 'android');
          expect(body['fcmToken'], fcmToken);
          return http.Response(jsonEncode({
            'deliveryKey': 'K' * 43,
            'expiresAt': DateTime.now().toUtc()
                .add(const Duration(days: 90)).toIso8601String(),
          }), 201);
        }
        return http.Response('{"error":"Unexpected request"}', 404);
      }),
    );
    await client.ready();
    // Parallel launch/resume callbacks MUST NOT rotate the native delivery
    // credential twice and leave the phone holding an invalid earlier grant.
    final concurrent = await Future.wait([
      client.registerAndroidBackgroundDelivery(),
      client.registerAndroidBackgroundDelivery(),
    ]);
    expect(concurrent, [true, true]);
    expect(client.backgroundDeliveryReady, true);
    expect(pushRegistrations, 1);
    expect(grantWrites, 1);
    expect(await client.registerAndroidBackgroundDelivery(), true);
    expect(pushRegistrations, 1);
    expect(grantWrites, 1);
    final pushHealth = await client.backgroundDeliveryHealth();
    expect(pushHealth?['registered'], true);
    expect(pushHealth?['lastProviderResult'], 'sent');
    expect(keys.records.values.single, contains('"pushDeviceId"'));
    client.dispose();
  });

  test('unconfigured server never creates a fake native background grant', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final keys = _Keys();
    messenger.setMockMethodCallHandler(notifications, (_) async => 'a' * 150);
    var saveCalls = 0;
    messenger.setMockMethodCallHandler(secure, (_) async {
      saveCalls++;
      return true;
    });
    String? handle;
    final client = PyreRcsClient(
      accountScope: 'pyresocial-rcs-primary-v1',
      secrets: keys,
      httpClient: MockClient((request) async {
        if (request.url.path == '/v1/identity/challenge') {
          handle = (jsonDecode(request.body) as Map)['handle'] as String;
          return http.Response(jsonEncode({'nonce': 'N' * 43}), 200);
        }
        if (request.url.path == '/v1/identity/enroll') {
          return http.Response(jsonEncode({
            'token': handle! + '.' + ('B' * 43),
            'expiresAt': DateTime.now().toUtc()
                .add(const Duration(days: 7)).toIso8601String(),
          }), 201);
        }
        if (request.url.path == '/v1/rcs/push/register') {
          return http.Response('{"error":"Native push transport not configured"}', 503);
        }
        return http.Response('{"error":"Unexpected"}', 404);
      }),
    );
    await client.ready();
    expect(await client.registerAndroidBackgroundDelivery(), false);
    expect(client.backgroundDeliveryReady, false);
    expect(saveCalls, 0);
    expect(client.handle, isNotNull); // RCS identity remains completely usable.
    client.dispose();
  });

  test('non-Android platforms never touch native FCM or secret channels', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(notifications, (_) async {
      fail('iOS client must not call Android FCM token registration');
    });
    final client = PyreRcsClient(accountScope: 'scope', secrets: _Keys());
    expect(await client.registerAndroidBackgroundDelivery(), false);
    client.dispose();
  });
}
