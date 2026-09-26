class CaptureSendTarget {
  const CaptureSendTarget({
    required this.conversationId,
    required this.recipientIds,
    required this.label,
  });

  final String conversationId;
  final List<String> recipientIds;
  final String label;

  bool get canPreselect =>
      conversationId.isNotEmpty && recipientIds.any((id) => id.trim().isNotEmpty);
}
