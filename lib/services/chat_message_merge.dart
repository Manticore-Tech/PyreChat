import 'package:pyrechat_flutter/models/chat_message.dart';

/// Merges a server refresh with optimistic local messages.
///
/// A successful POST can be acknowledged before the following GET sees it.
/// Keeping local echoes until the same server id appears prevents a just-sent
/// message from disappearing during that consistency window.
List<ChatMessage> mergeThreadMessages({
  required List<ChatMessage> remote,
  required List<ChatMessage> current,
}) {
  final remoteIds = remote.map((m) => m.id).toSet();
  final localOnly = current.where(
    (m) => m.localEcho && !remoteIds.contains(m.id),
  );

  final merged = <ChatMessage>[...remote, ...localOnly];
  merged.sort((a, b) {
    final aTime = DateTime.tryParse(a.createdAt);
    final bTime = DateTime.tryParse(b.createdAt);
    if (aTime == null || bTime == null) return 0;
    return aTime.compareTo(bTime);
  });
  return merged;
}
