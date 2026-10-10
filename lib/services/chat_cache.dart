import 'dart:convert';

import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/services/secure_blob_store.dart';

class ChatCache {
  ChatCache({SecureBlobStore? store})
      : _store = store ?? const PlatformSecureBlobStore();

  static final ChatCache instance = ChatCache();

  static const _schemaVersion = 1;
  static const _maxMessagesPerThread = 300;

  final SecureBlobStore _store;

  String _keyPart(String value) {
    return base64UrlEncode(utf8.encode(value)).replaceAll('=', '');
  }

  String _chatsKey(String userId) =>
      'chat_cache_v1_${_keyPart(userId)}_list';

  String _messagesKey(String userId, String chatId) =>
      'chat_cache_v1_${_keyPart(userId)}_${_keyPart(chatId)}_messages';

  Future<List<ChatPreview>?> readChats(String userId) async {
    if (userId.trim().isEmpty || !await _store.isSupported) return null;
    final raw = await _store.read(_chatsKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _schemaVersion ||
          decoded['items'] is! List<dynamic>) {
        await _store.delete(_chatsKey(userId));
        return null;
      }
      return (decoded['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatPreview.fromCacheJson)
          .where((chat) => chat.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await _store.delete(_chatsKey(userId));
      return null;
    }
  }

  Future<void> writeChats(String userId, List<ChatPreview> chats) async {
    if (userId.trim().isEmpty || !await _store.isSupported) return;
    final payload = jsonEncode({
      'version': _schemaVersion,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'items': chats.map((chat) => chat.toCacheJson()).toList(growable: false),
    });
    await _store.write(_chatsKey(userId), payload);
  }

  Future<List<ChatMessage>?> readMessages(
    String userId,
    String chatId,
  ) async {
    if (userId.trim().isEmpty ||
        chatId.trim().isEmpty ||
        !await _store.isSupported) {
      return null;
    }
    final raw = await _store.read(_messagesKey(userId, chatId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _schemaVersion ||
          decoded['items'] is! List<dynamic>) {
        await _store.delete(_messagesKey(userId, chatId));
        return null;
      }
      return (decoded['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .where((message) => message.id.isNotEmpty)
          .map(
            (message) => message.deliveryState == ChatDeliveryState.sending
                ? message.copyWith(deliveryState: ChatDeliveryState.queued)
                : message,
          )
          .toList(growable: false);
    } catch (_) {
      await _store.delete(_messagesKey(userId, chatId));
      return null;
    }
  }

  Future<void> writeMessages(
    String userId,
    String chatId,
    List<ChatMessage> messages,
  ) async {
    if (userId.trim().isEmpty ||
        chatId.trim().isEmpty ||
        !await _store.isSupported) {
      return;
    }
    final start = messages.length > _maxMessagesPerThread
        ? messages.length - _maxMessagesPerThread
        : 0;
    final retained = messages.sublist(start);
    final payload = jsonEncode({
      'version': _schemaVersion,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'items':
          retained.map((message) => message.toCacheJson()).toList(growable: false),
    });
    await _store.write(_messagesKey(userId, chatId), payload);
  }

  Future<void> deleteThread(String userId, String chatId) async {
    if (userId.trim().isEmpty || chatId.trim().isEmpty) return;
    await _store.delete(_messagesKey(userId, chatId));
  }

  Future<void> clearUser(String userId) async {
    if (userId.trim().isEmpty) return;
    final chats = await readChats(userId) ?? const <ChatPreview>[];
    for (final chat in chats) {
      await deleteThread(userId, chat.id);
    }
    await _store.delete(_chatsKey(userId));
  }
}
