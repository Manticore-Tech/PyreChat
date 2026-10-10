import 'package:pyrechat_flutter/models/chat_message.dart';

/// Merges a server refresh with messages already visible in the thread.
///
/// A successful POST or realtime event can become visible before a following GET
/// observes the same row. Keep optimistic local echoes indefinitely until the
/// server returns their id, and keep any other very recent visible message for a
/// short grace window so a stale refresh cannot make it flash away.
List<ChatMessage> mergeThreadMessages({
  required List<ChatMessage> remote,
  required List<ChatMessage> current,
  DateTime? now,
  Duration recentGrace = const Duration(seconds: 12),
}) {
  final remoteIds = remote.map((m) => m.id).toSet();
  final referenceNow = (now ?? DateTime.now()).toUtc();

  final localOnly = current.where((message) {
    if (remoteIds.contains(message.id)) return false;
    if (message.localEcho) return true;

    final createdAt = DateTime.tryParse(message.createdAt)?.toUtc();
    if (createdAt == null) return false;

    final age = referenceNow.difference(createdAt);
    return age >= Duration.zero && age <= recentGrace;
  });

  final mergedById = <String, ChatMessage>{
    for (final message in remote) message.id: message,
    for (final message in localOnly) message.id: message,
  };
  final merged = mergedById.values.toList();
  merged.sort((a, b) {
    final aTime = DateTime.tryParse(a.createdAt);
    final bTime = DateTime.tryParse(b.createdAt);
    if (aTime == null || bTime == null) return 0;
    return aTime.compareTo(bTime);
  });
  return merged;
}

/// Reconciles an optimistic local message after an idempotent send returns its
/// canonical server id.
///
/// A reconnect refresh can reveal the server copy before the retry response
/// arrives. In that race, prefer the already-visible server copy and remove the
/// local temp echo instead of briefly persisting/rendering both rows.
List<ChatMessage> reconcileDeliveredLocalEcho({
  required List<ChatMessage> current,
  required String localId,
  required String serverId,
}) {
  ChatMessage? local;
  ChatMessage? server;

  for (final message in current) {
    if (message.id == localId) local = message;
    if (message.id == serverId && message.id != localId) server = message;
  }

  if (local == null) return current;

  final replacement =
      server ??
      local.copyWith(
        id: serverId,
        deliveryState: ChatDeliveryState.delivered,
        localEcho: true,
      );

  final reconciled = <ChatMessage>[];
  var insertedReplacement = false;
  for (final message in current) {
    if (message.id == localId || message.id == serverId) {
      if (!insertedReplacement) {
        reconciled.add(replacement);
        insertedReplacement = true;
      }
      continue;
    }
    reconciled.add(message);
  }
  return reconciled;
}
