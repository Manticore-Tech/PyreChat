import 'package:shared_preferences/shared_preferences.dart';

enum ChatPinPosition { none, top, bottom }

class ChatOrderPrefs {
  ChatOrderPrefs({SharedPreferences? prefs}) : _prefsFuture = prefs == null
      ? SharedPreferences.getInstance()
      : Future.value(prefs);

  static const _topKey = 'pyre_chat_pin_top_v1';
  static const _bottomKey = 'pyre_chat_pin_bottom_v1';

  final Future<SharedPreferences> _prefsFuture;

  Future<ChatPinPosition> positionFor(String chatId) async {
    final prefs = await _prefsFuture;
    final top = prefs.getStringList(_topKey) ?? const [];
    if (top.contains(chatId)) return ChatPinPosition.top;
    final bottom = prefs.getStringList(_bottomKey) ?? const [];
    if (bottom.contains(chatId)) return ChatPinPosition.bottom;
    return ChatPinPosition.none;
  }

  Future<Map<String, ChatPinPosition>> positionsFor(
    Iterable<String> chatIds,
  ) async {
    final prefs = await _prefsFuture;
    final top = (prefs.getStringList(_topKey) ?? const []).toSet();
    final bottom = (prefs.getStringList(_bottomKey) ?? const []).toSet();
    return {
      for (final id in chatIds)
        id: top.contains(id)
            ? ChatPinPosition.top
            : bottom.contains(id)
                ? ChatPinPosition.bottom
                : ChatPinPosition.none,
    };
  }

  Future<void> setPosition(String chatId, ChatPinPosition position) async {
    final prefs = await _prefsFuture;
    final top = (prefs.getStringList(_topKey) ?? const []).toSet();
    final bottom = (prefs.getStringList(_bottomKey) ?? const []).toSet();

    top.remove(chatId);
    bottom.remove(chatId);

    switch (position) {
      case ChatPinPosition.none:
        break;
      case ChatPinPosition.top:
        top.add(chatId);
      case ChatPinPosition.bottom:
        bottom.add(chatId);
    }

    await prefs.setStringList(_topKey, top.toList(growable: false));
    await prefs.setStringList(_bottomKey, bottom.toList(growable: false));
  }
}
