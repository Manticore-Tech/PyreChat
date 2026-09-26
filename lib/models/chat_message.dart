enum ChatDeliveryState { delivered, sending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.createdAt,
    required this.displayName,
    required this.username,
    this.mediaKey,
    this.snapKind,
    this.viewedAt,
    this.openedAt,
    this.screenshotAt,
    this.deliveryState = ChatDeliveryState.delivered,
    this.localEcho = false,
  });

  final String id;
  final String senderId;
  final String kind;
  final String body;
  final String createdAt;
  final String displayName;
  final String username;
  final String? mediaKey;
  final String? snapKind;
  final String? viewedAt;
  final String? openedAt;
  final String? screenshotAt;
  final ChatDeliveryState deliveryState;
  final bool localEcho;

  bool get isSnap => kind == 'snap';

  bool isUnopenedFor(String meId) =>
      isSnap && senderId != meId && viewedAt == null;

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? kind,
    String? body,
    String? createdAt,
    String? displayName,
    String? username,
    String? mediaKey,
    String? snapKind,
    String? viewedAt,
    String? openedAt,
    String? screenshotAt,
    ChatDeliveryState? deliveryState,
    bool? localEcho,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      mediaKey: mediaKey ?? this.mediaKey,
      snapKind: snapKind ?? this.snapKind,
      viewedAt: viewedAt ?? this.viewedAt,
      openedAt: openedAt ?? this.openedAt,
      screenshotAt: screenshotAt ?? this.screenshotAt,
      deliveryState: deliveryState ?? this.deliveryState,
      localEcho: localEcho ?? this.localEcho,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      kind: json['kind'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      displayName:
          (json['display_name'] as String?) ?? json['username'] as String? ?? '',
      username: json['username'] as String? ?? '',
      mediaKey: json['media_key'] as String?,
      snapKind: json['snap_kind'] as String?,
      viewedAt: json['viewed_at'] as String?,
      openedAt: json['opened_at'] as String?,
      screenshotAt: json['screenshot_at'] as String?,
    );
  }
}
