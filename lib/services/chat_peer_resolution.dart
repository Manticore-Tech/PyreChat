/// Finds the other user for direct-chat safety actions even when a chat
/// preview's member/avatar metadata is missing.
///
/// Only message senders already present in this thread may be used as a
/// fallback. Never infer a user to block or report from a group thread.
String? resolveDirectChatPeerId({
  required String meId,
  required bool requiresPrivateText,
  String? peerUserId,
  required Iterable<String> messageSenderIds,
}) {
  if (!requiresPrivateText) return null;
  final self = meId.trim();
  final explicit = peerUserId?.trim();
  if (explicit != null && explicit.isNotEmpty && explicit != self) {
    return explicit;
  }

  for (final rawSenderId in messageSenderIds) {
    final senderId = rawSenderId.trim();
    if (senderId.isNotEmpty && senderId != self) return senderId;
  }
  return null;
}
