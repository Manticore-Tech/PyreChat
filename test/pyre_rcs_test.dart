// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pyrechat_flutter/services/pyre_rcs.dart';
import 'package:pyrechat_flutter/services/secure_blob_store.dart';

class _Secrets implements SecureBlobStore {
  final values = <String, String>{};
  bool supported = true;

  @override
  Future<bool> get isSupported async => supported;

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<bool> write(String name, String value) async {
    if (!supported) return false;
    values[name] = value;
    return true;
  }

  @override
  Future<void> delete(String name) async {
    values.remove(name);
  }
}

void main() {
  test('message status labels require delivery evidence', () {
    expect(PyreRcsProtocol.messageStatusLabel('queued'), 'Sent');
    expect(PyreRcsProtocol.messageStatusLabel('sent'), 'Sent');
    expect(PyreRcsProtocol.messageStatusLabel('server-accepted'), 'Sent');
    expect(PyreRcsProtocol.messageStatusLabel('delivered'), 'Delivered');
    expect(PyreRcsProtocol.messageStatusLabel('displayed'), 'Read');
    expect(PyreRcsProtocol.messageStatusLabel('failed'), 'Failed');
  });

  test('CPIM builder, Unicode, original IDs and peer parsing match Worker', () {
    final raw = PyreRcsProtocol.cpim(
      from: 'alice',
      to: 'bob',
      id: 'message1234567890',
      mime: 'text/plain; charset=utf-8',
      content: 'Hey 😄',
    );
    expect(raw, contains('From: <sip:alice@messages.pyre.social>\r\n'));
    expect(raw, contains('To: <sip:bob@messages.pyre.social>\r\n'));
    expect(raw, contains('\r\n\r\nContent-type: text/plain; charset=utf-8\r\n\r\nHey 😄'));
    final incoming = PyreRcsProtocol.parse({
      'cpim': raw,
      'state': 'stored',
      'createdAt': '2026-10-09T00:00:00.000Z',
      'sequence': 4,
    }, 'bob');
    expect(incoming, isNotNull);
    expect(incoming!.peer, 'alice');
    expect(incoming.incoming, isTrue);
    expect(incoming.body, 'Hey 😄');
    expect(incoming.id, 'message1234567890');

    final outgoing = PyreRcsProtocol.parse({'cpim': raw}, 'alice');
    expect(outgoing!.incoming, isFalse);
    expect(outgoing.peer, 'bob');
    expect(PyreRcsProtocol.parse({'cpim': raw}, 'charlie'), isNull);
  });

  test('SIP REGISTER over WSS uses the correct Pyre account and RFC headers', () {
    final frame = PyreRcsProtocol.register('alice');
    expect(frame, startsWith(
      'REGISTER sip:alice@messages.pyre.social SIP/2.0\r\n',
    ));
    expect(frame, contains('Via: SIP/2.0/WSS messages.pyre.social;branch=z9hG4bK'));
    expect(frame, contains('From: <sip:alice@messages.pyre.social>;tag='));
    expect(frame, contains('To: <sip:alice@messages.pyre.social>\r\n'));
    expect(frame, contains('CSeq: 1 REGISTER\r\n'));
    expect(frame, endsWith('Content-Length: 0\r\n\r\n'));
  });

  test('copied SIP address can be pasted into the peer field', () {
    expect(PyreRcsProtocol.peerHandle('alice'), 'alice');
    expect(PyreRcsProtocol.peerHandle(
      '  sip:alice@messages.pyre.social  '), 'alice');
    expect(() => PyreRcsProtocol.peerHandle('sip:alice@evil.net'),
        throwsA(isA<PyreRcsException>()));
    expect(() => PyreRcsProtocol.peerHandle(
      'sip:alice@messages.pyre.social;transport=udp'),
        throwsA(isA<PyreRcsException>()));
  });

  test('rejects invalid handles, IDs, oversized messages and event bubbles', () {
    expect(() => PyreRcsProtocol.handle('Alice'), throwsA(isA<PyreRcsException>()));
    expect(() => PyreRcsProtocol.handle('../bob'), throwsA(isA<PyreRcsException>()));
    expect(() => PyreRcsProtocol.handle('sip:bob@evil.com'),
        throwsA(isA<PyreRcsException>()));
    expect(() => PyreRcsProtocol.cpim(
      from: 'alice', to: 'bob', id: 'short', mime: 'text/plain; charset=utf-8',
      content: 'hello',
    ), throwsA(isA<PyreRcsException>()));
    expect(() => PyreRcsProtocol.cpim(
      from: 'alice', to: 'bob', id: 'message1234567890',
      mime: 'text/plain; charset=utf-8', content: 'x' * 65537,
    ), throwsA(isA<PyreRcsException>()));
    final composing = PyreRcsProtocol.cpim(
      from: 'alice', to: 'bob', id: 'typing12345678900',
      mime: 'application/im-iscomposing+xml',
      content: PyreRcsProtocol.composingXml(true),
    );
    expect(PyreRcsProtocol.parse({'cpim': composing}, 'bob'), isNull);
    expect(PyreRcsProtocol.receiptXml('message1234567890', true),
        contains('<displayed/>'));
  });

  test('RCS enrollment closed retains signing identity; no plaintext fallback', () async {
    final store = _Secrets();
    final requests = <http.Request>[];
    final client = PyreRcsClient(
      accountScope: 'pyre-user-1',
      secrets: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{"error":"Enrollment temporarily closed"}', 403,
            headers: {'content-type': 'application/json'});
      }),
    );
    await expectLater(client.ready(), throwsA(isA<PyreRcsException>()));
    final first = client.handle;
    expect(first, matches(RegExp(r'^r[a-f0-9]{24}$')));
    expect(store.values, hasLength(1));
    expect(store.values.values.single, contains('"enrolled":false'));
    await expectLater(client.ready(), throwsA(isA<PyreRcsException>()));
    expect(client.handle, first);
    expect(requests, hasLength(2));
    expect(requests.every((item) => item.url.path == '/v1/identity/challenge'), isTrue);
    client.dispose();
  });

  test('no secure storage refuses RCS keys or sessions', () async {
    final secrets = _Secrets()..supported = false;
    final client = PyreRcsClient(
      accountScope: 'someone',
      secrets: secrets,
      httpClient: MockClient((_) async {
        fail('Network must not run without secure storage.');
      }),
    );
    await expectLater(client.ready(), throwsA(isA<PyreRcsException>()));
    expect(secrets.values, isEmpty);
    client.dispose();
  });

  test('signed Ed25519 enrollment and direct CPIM transport work with service contract', () async {
    final secrets = _Secrets();
    final nonce = 'N' * 43;
    final captured = <String>[];
    String? account;
    var signatures = 0;
    var registered = false;
    final client = PyreRcsClient(
      accountScope: 'user-a',
      secrets: secrets,
      httpClient: MockClient((req) async {
        final path = req.url.path;
        final json = req.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(req.body) as Map<String, dynamic>;
        if (path == '/v1/identity/challenge') {
          account = json['handle'] as String;
          expect(json['intent'], registered ? 'session' : 'enroll');
          return http.Response(jsonEncode({'nonce': nonce}), 200);
        }
        if (path == '/v1/identity/enroll' || path == '/v1/identity/session') {
          final claimedHandle = json['handle'] as String;
          expect(claimedHandle, account);
          final intent = path.endsWith('enroll') ? 'enroll' : 'session';
          final publicBytes = registered
              ? base64Url.decode(base64Url.normalize(
                  (jsonDecode(secrets.values.values.single) as Map<String, dynamic>)
                      ['publicKey'] as String))
              : base64Url.decode(base64Url.normalize(json['publicKey'] as String));
          final sig = Signature(
            base64Url.decode(base64Url.normalize(json['signature'] as String)),
            publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
          );
          final valid = await Ed25519().verify(
            utf8.encode(PyreRcsProtocol.challengeText(intent, claimedHandle, nonce)),
            signature: sig,
          );
          expect(valid, isTrue);
          signatures++;
          registered = true;
          return http.Response(jsonEncode({
            'token': claimedHandle + '.' + ('Z' * 43),
            'expiresAt': DateTime.now().toUtc().add(const Duration(days: 7))
                .toIso8601String(),
          }), 201);
        }
        if (path == '/v1/rcs/messages' && req.method == 'POST') {
          expect(req.headers['authorization'], startsWith('Bearer ' + account!));
          captured.add(json['cpim'] as String);
          return http.Response('{"id":"outgoing12345678","state":"server-accepted"}',
              202);
        }
        if (path == '/v1/rcs/messages' && req.method == 'GET') {
          expect(req.headers['authorization'], startsWith('Bearer ' + account!));
          return http.Response(jsonEncode({
            'messages': [{
              'cpim': PyreRcsProtocol.cpim(
                from: 'bob', to: account!,
                id: 'incoming1234567890',
                mime: 'text/plain; charset=utf-8',
                content: 'Welcome',
              ),
              'sequence': 1,
              'state': 'stored',
              'createdAt': '2026-10-09T00:00:00.000Z',
            }],
            'nextCursor': null,
          }), 200);
        }
        if (path == '/v1/rcs/status') {
          return http.Response('{"state":"delivered"}', 200);
        }
        return http.Response('{"error":"Unexpected route"}', 404);
      }),
    );
    await client.ready();
    expect(signatures, 1);
    expect(client.handle, account);
    expect(secrets.values.values.single, contains('"enrolled":true'));
    final outbound = await client.send('bob', 'Hello 😄');
    expect(outbound['state'], 'server-accepted');
    expect(captured.single, contains('Hello 😄'));
    expect(captured.single, contains('From: <sip:' + account!));
    final messages = await client.history();
    expect(messages, hasLength(1));
    expect(messages.single.peer, 'bob');
    expect(messages.single.body, 'Welcome');
    expect(await client.status('outgoing12345678'), 'delivered');
    await client.acknowledge('bob', 'incoming1234567890');
    expect(captured.last, contains('Content-type: message/imdn+xml'));
    await client.typing('bob', active: true);
    expect(captured.last, contains('application/im-iscomposing+xml'));
    client.dispose();
  });
}
