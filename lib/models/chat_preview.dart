enum ChatAvatarKind { person, group, channel }

class ChatPreview {
  const ChatPreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.timeLabel,
    this.unread = 0,
    this.avatarKind = ChatAvatarKind.person,
    this.avatarInitials,
    this.avatarHue,
    this.lastKind = 'text',
    this.lastSenderId,
    this.lastOpenedAt,
    this.muted = false,
    this.memberIds = const [],
  });

  final String id;
  final String title;
  final String preview;
  final String timeLabel;
  final int unread;
  final ChatAvatarKind avatarKind;
  final String? avatarInitials;
  final double? avatarHue;
  final String lastKind;
  final String? lastSenderId;
  final String? lastOpenedAt;
  final bool muted;
  final List<String> memberIds;

  bool lastFromMe(String meId) => lastSenderId != null && lastSenderId == meId;

  List<String> recipientIdsFor(String meId) =>
      memberIds.where((id) => id.isNotEmpty && id != meId).toList(growable: false);

  static String? _memberId(Map<String, dynamic> member) {
    final raw = member['id'] ?? member['user_id'] ?? member['userId'];
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _memberLabel(Map<String, dynamic> member) {
    final displayName = (member['display_name'] ?? member['displayName']) as String?;
    final username = member['username'] as String?;
    if (displayName?.trim().isNotEmpty == true) return displayName!.trim();
    if (username?.trim().isNotEmpty == true) return username!.trim();
    return 'Chat';
  }

  factory ChatPreview.fromApi(
    Map<String, dynamic> json, {
    String? meId,
  }) {
    final isGroup = (json['is_group'] as num?)?.toInt() == 1 || json['isGroup'] == true;
    final members = (json['members'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final last = json['last'] as Map<String, dynamic>?;

    final memberIds = <String>{};
    for (final member in members) {
      final id = _memberId(member);
      if (id != null) memberIds.add(id);
    }

    final visibleMembers = meId == null || meId.isEmpty
        ? members
        : members.where((member) => _memberId(member) != meId).toList(growable: false);

    final title = isGroup
        ? ((json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : 'Group')
        : (visibleMembers.isNotEmpty
            ? _memberLabel(visibleMembers.first)
            : (members.isNotEmpty ? _memberLabel(members.first) : 'Chat'));
    final initials = title.isNotEmpty ? title[0] : '?';
    final hue = (title.hashCode % 360).toDouble().abs();

    var preview = 'Say hi';
    if (last != null) {
      final kind = last['kind'] as String? ?? 'text';
      final body = (last['body'] as String?)?.trim() ?? '';
      if (kind == 'text' && body.isNotEmpty) {
        preview = body;
      } else if (kind == 'image') {
        preview = 'Photo';
      } else if (kind == 'video') {
        preview = 'Video';
      } else if (kind == 'snap') {
        preview = 'Pyre';
      } else {
        preview = 'New message';
      }
    }

    var timeLabel = '';
    final iso = last?['created_at'] as String? ?? json['created_at'] as String?;
    if (iso != null && iso.isNotEmpty) {
      final dt = DateTime.tryParse(iso);
      if (dt != null) {
        final local = dt.toLocal();
        final now = DateTime.now();
        final diff = now.difference(local);
        if (diff.inMinutes < 1) {
          timeLabel = 'now';
        } else if (diff.inMinutes < 60) {
          timeLabel = '${diff.inMinutes}m';
        } else if (diff.inHours < 24) {
          timeLabel = '${diff.inHours}h';
        } else if (diff.inDays < 7) {
          timeLabel = '${diff.inDays}d';
        } else if (diff.inDays < 14) {
          timeLabel = '1w';
        } else {
          timeLabel = '${local.month}/${local.day}';
        }
      }
    }

    final lastKind = last?['kind'] as String? ?? 'text';
    final lastSenderId = last?['sender_id'] as String?;
    final lastOpenedAt = last?['opened_at'] as String?;

    return ChatPreview(
      id: json['id'] as String,
      title: title,
      preview: preview,
      timeLabel: timeLabel,
      unread: (json['unopenedSnaps'] as num?)?.toInt() ?? 0,
      avatarKind: isGroup ? ChatAvatarKind.group : ChatAvatarKind.person,
      avatarInitials: isGroup ? null : initials,
      avatarHue: isGroup ? null : hue,
      lastKind: lastKind,
      lastSenderId: lastSenderId,
      lastOpenedAt: lastOpenedAt,
      muted: json['muted'] == true,
      memberIds: memberIds.toList(growable: false),
    );
  }
}
