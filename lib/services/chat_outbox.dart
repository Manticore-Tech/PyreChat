import 'dart:convert';
import 'dart:math';

import 'package:pyrechat_flutter/models/chat_message.dart';

List<ChatMessage> queuedTextMessagesForRetry(
  List<ChatMessage> messages, {
  required String senderId,
}) {
  return messages
      .where(
        (message) =>
            message.senderId == senderId &&
            message.kind == 'text' &&
            message.localEcho &&
            message.deliveryState == ChatDeliveryState.queued,
      )
      .toList(growable: false);
}

/// Cryptographically random 192-bit id, reused unchanged for every send retry.
/// Accepted by both the server's idempotency key validator and MLS envelope.
String newOutgoingClientMessageId() {
  final secureRandom = Random.secure();
  final bytes = List<int>.generate(24, (_) => secureRandom.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
