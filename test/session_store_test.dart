import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/secure_token_store.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureTokenStore implements SecureTokenStore {
  _FakeSecureTokenStore({
    this.supported = true,
    this.token,
    this.writeSucceeds = true,
  });

  bool supported;
  String? token;
  bool writeSucceeds;
  int writes = 0;
  int deletes = 0;

  @override
  Future<bool> get isSupported async => supported;

  @override
  Future<String?> read() async => token;

  @override
  Future<bool> write(String value) async {
    writes++;
    if (!writeSucceeds) return false;
    token = value;
    return true;
  }

  @override
  Future<void> delete() async {
    deletes++;
    token = null;
  }
}

void main() {
  const user = PyreUser(
    id: 'user-1',
    username: 'phoenix',
    displayName: 'Phoenix',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('corrupt cached user is discarded instead of crashing startup', () async {
    SharedPreferences.setMockInitialValues({
      'pyre_token': 'token',
      'pyre_user': '{not-json',
    });

    final store = SessionStore(
      secureTokenStore: _FakeSecureTokenStore(supported: false),
    );
    expect(await store.user, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pyre_user'), isNull);
    expect(await store.token, 'token');
  });

  test('legacy plaintext token migrates into secure storage on first read', () async {
    SharedPreferences.setMockInitialValues({
      'pyre_token': 'legacy-token',
    });
    final secure = _FakeSecureTokenStore();
    final store = SessionStore(secureTokenStore: secure);

    expect(await store.token, 'legacy-token');
    expect(secure.token, 'legacy-token');
    expect(secure.writes, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pyre_token'), isNull);
  });

  test('secure token wins and removes any leftover plaintext copy', () async {
    SharedPreferences.setMockInitialValues({
      'pyre_token': 'old-plaintext-token',
    });
    final secure = _FakeSecureTokenStore(token: 'secure-token');
    final store = SessionStore(secureTokenStore: secure);

    expect(await store.token, 'secure-token');
    expect(secure.writes, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pyre_token'), isNull);
  });

  test('save keeps bearer token out of SharedPreferences when secure storage works',
      () async {
    final secure = _FakeSecureTokenStore();
    final store = SessionStore(secureTokenStore: secure);

    await store.save(token: 'new-token', user: user);

    expect(secure.token, 'new-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pyre_token'), isNull);
    expect(prefs.getString('pyre_user'), isNotNull);
  });

  test('save falls back without losing session when secure write fails', () async {
    final secure = _FakeSecureTokenStore(writeSucceeds: false);
    final store = SessionStore(secureTokenStore: secure);

    await store.save(token: 'fallback-token', user: user);

    expect(secure.token, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pyre_token'), 'fallback-token');
  });

  test('clear removes secure token and all legacy session state', () async {
    SharedPreferences.setMockInitialValues({
      'pyre_token': 'legacy-token',
      'pyre_user': '{"id":"user-1","username":"phoenix","displayName":"Phoenix"}',
    });
    final secure = _FakeSecureTokenStore(token: 'secure-token');
    final store = SessionStore(secureTokenStore: secure);

    await store.clear();

    expect(secure.token, isNull);
    expect(secure.deletes, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pyre_token'), isNull);
    expect(prefs.getString('pyre_user'), isNull);
  });
}
