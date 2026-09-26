/// In-memory chat drafts for the current app session.
///
/// Drafts deliberately stay out of SharedPreferences so private plaintext is not
/// added to persistent storage before PyreChat has an encrypted local database.
class ChatDraftStore {
  ChatDraftStore._();

  static final ChatDraftStore instance = ChatDraftStore._();

  final Map<String, String> _drafts = <String, String>{};

  int get draftCount => _drafts.length;

  bool get hasDrafts => _drafts.isNotEmpty;

  String draftFor(String chatId) => _drafts[chatId] ?? '';

  void setDraft(String chatId, String text) {
    if (text.isEmpty) {
      _drafts.remove(chatId);
    } else {
      _drafts[chatId] = text;
    }
  }

  void clear(String chatId) => _drafts.remove(chatId);

  void clearAll() => _drafts.clear();
}
