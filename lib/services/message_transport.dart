import 'package:pyrechat_flutter/models/chat_message.dart';

/// Transport boundary for chat history, delivery receipts and outbound text.
///
/// The current adapter preserves the established authenticated Pyre API. The
/// independent messaging Worker can replace this adapter without changing chat
/// screens, session storage, encryption engines, or message models.
abstract class PyreMessageTransport {
  Future<List<ChatMessage>> messages(String chatId);
  Future<bool> isEncrypted(String chatId);
  Future<void> acknowledge({
    required String chatId,
    required List<String> messageIds,
    required bool read,
  });
  Future<String> sendText({
    required String chatId,
    required String text,
    String? clientId,
  });
  Future<String> sendEncrypted({
    required String chatId,
    required String ciphertext,
    required String clientId,
  });
}

typedef PyreMessageGet = Future<Map<String, dynamic>> Function(String path);
typedef PyreMessagePost = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, dynamic> payload,
);

/// Compatibility adapter: same production API and same anti-plaintext-fallback
/// guarantees. Never tries a standard send when an encrypted send fails.
class LegacyPyreMessageTransport implements PyreMessageTransport {
  LegacyPyreMessageTransport({required this.get, required this.post});

  final PyreMessageGet get;
  final PyreMessagePost post;

  // Treat chat identifiers as one URL segment, never a route or query suffix.
  String _chatPath(String chatId, String suffix) =>
      '/api/chats/${Uri.encodeComponent(chatId)}/$suffix';

  @override
  Future<List<ChatMessage>> messages(String chatId) async {
    final result = await get(_chatPath(chatId, 'messages'));
    final values = result['messages'] as List<dynamic>? ?? [];
    return values
        .map((value) => ChatMessage.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<bool> isEncrypted(String chatId) async {
    final result = await get(_chatPath(chatId, 'encryption'));
    final encrypted = result['e2eeEnabled'];
    // Missing or malformed metadata must never authorize a plaintext send.
    if (encrypted is! bool) {
      throw StateError('Chat encryption status is unavailable');
    }
    return encrypted;
  }

  @override
  Future<void> acknowledge({
    required String chatId,
    required List<String> messageIds,
    required bool read,
  }) async {
    if (messageIds.isEmpty) return;
    await post(_chatPath(chatId, 'receipts'), {
      'messageIds': messageIds,
      'read': read,
    });
  }

  @override
  Future<String> sendText({
    required String chatId,
    required String text,
    String? clientId,
  }) async {
    // Fail closed in an MLS chat, even if a caller accidentally chooses the
    // standard transport. The backend remains the final race-safe guard.
    if (await isEncrypted(chatId)) {
      throw StateError('Standard text is unavailable in encrypted chats');
    }
    final result = await post(_chatPath(chatId, 'messages'), {
      'kind': 'text',
      'body': text,
      if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
    });
    return result['id'] as String;
  }

  @override
  Future<String> sendEncrypted({
    required String chatId,
    required String ciphertext,
    required String clientId,
  }) async {
    final result = await post(_chatPath(chatId, 'messages'), {
      'kind': 'mls',
      'body': ciphertext,
      'clientId': clientId,
    });
    return result['id'] as String;
  }
}
