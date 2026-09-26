import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/chat_order_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('chat can move between top bottom and normal positions', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ChatOrderPrefs(prefs: prefs);

    expect(await store.positionFor('a'), ChatPinPosition.none);

    await store.setPosition('a', ChatPinPosition.top);
    expect(await store.positionFor('a'), ChatPinPosition.top);

    await store.setPosition('a', ChatPinPosition.bottom);
    expect(await store.positionFor('a'), ChatPinPosition.bottom);

    await store.setPosition('a', ChatPinPosition.none);
    expect(await store.positionFor('a'), ChatPinPosition.none);
  });

  test('positionsFor returns independent positions', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ChatOrderPrefs(prefs: prefs);

    await store.setPosition('top', ChatPinPosition.top);
    await store.setPosition('bottom', ChatPinPosition.bottom);

    final positions = await store.positionsFor(['top', 'middle', 'bottom']);
    expect(positions['top'], ChatPinPosition.top);
    expect(positions['middle'], ChatPinPosition.none);
    expect(positions['bottom'], ChatPinPosition.bottom);
  });
}
