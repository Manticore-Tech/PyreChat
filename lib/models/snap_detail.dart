class SnapDetail {
  const SnapDetail({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.caption,
    required this.mediaUrl,
    required this.displayName,
  });

  final String id;
  final String senderId;
  final String kind;
  final String caption;
  final String mediaUrl;
  final String displayName;

  factory SnapDetail.fromJson(Map<String, dynamic> json, String origin) {
    final rawUrl = json['url'] as String? ?? '';
    final mediaUrl = rawUrl.startsWith('http') ? rawUrl : '$origin$rawUrl';
    return SnapDetail(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      kind: json['kind'] as String? ?? 'photo',
      caption: json['caption'] as String? ?? '',
      mediaUrl: mediaUrl,
      displayName: (json['display_name'] as String?) ?? 'Friend',
    );
  }
}
