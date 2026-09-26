import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/chat_draft_store.dart';

void main() {
  setUp(ChatDraftStore.instance.clearAll);

  test('drafts stay available for the current app session', () {
    ChatDraftStore.instance.setDraft('chat-1', 'unfinished message');
    expect(ChatDraftStore.instance.draftFor('chat-1'), 'unfinished message');
  });

  test('empty drafts are removed instead of retained', () {
    ChatDraftStore.instance.setDraft('chat-1', 'hello');
    ChatDraftStore.instance.setDraft('chat-1', '');
    expect(ChatDraftStore.instance.draftFor('chat-1'), isEmpty);
  });

  test('draft count tracks only non-empty drafts', () {
    expect(ChatDraftStore.instance.draftCount, 0);
    expect(ChatDraftStore.instance.hasDrafts, isFalse);

    ChatDraftStore.instance.setDraft('chat-1', 'one');
    ChatDraftStore.instance.setDraft('chat-2', 'two');
    expect(ChatDraftStore.instance.draftCount, 2);
    expect(ChatDraftStore.instance.hasDrafts, isTrue);

    ChatDraftStore.instance.setDraft('chat-1', '');
    expect(ChatDraftStore.instance.draftCount, 1);

    ChatDraftStore.instance.clearAll();
    expect(ChatDraftStore.instance.draftCount, 0);
    expect(ChatDraftStore.instance.hasDrafts, isFalse);
  });
}
