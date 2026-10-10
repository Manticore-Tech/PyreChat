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
    this.avatarUserId,
    this.avatarUrl,
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
  final String? avatarUserId;
  final String? avatarUrl;
  final String lastKind;
  final String? lastSenderId;
  final String? lastOpenedAt;
  final bool muted;
  final List<String> memberIds;

  /// Missing peer avatar metadata must not remove a direct chat's MLS requirement.
  bool get requiresPrivateText => avatarKind == ChatAvatarKind.person;

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

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'title': title,
        'preview': preview,
        'timeLabel': timeLabel,
        'unread': unread,
        'avatarKind': avatarKind.name,
        if (avatarInitials != null) 'avatarInitials': avatarInitials,
        if (avatarHue != null) 'avatarHue': avatarHue,
        if (avatarUserId != null) 'avatarUserId': avatarUserId,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'lastKind': lastKind,
        if (lastSenderId != null) 'lastSenderId': lastSenderId,
        if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt,
        'muted': muted,
        'memberIds': memberIds,
      };

  factory ChatPreview.fromCacheJson(Map<String, dynamic> json) {
    final avatarKindName = json['avatarKind']?.toString();
    final avatarKind = ChatAvatarKind.values.firstWhere(
      (value) => value.name == avatarKindName,
      orElse: () => ChatAvatarKind.person,
    );
    return ChatPreview(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Chat',
      preview: json['preview']?.toString() ?? '',
      timeLabel: json['timeLabel']?.toString() ?? '',
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      avatarKind: avatarKind,
      avatarInitials: json['avatarInitials']?.toString(),
      avatarHue: (json['avatarHue'] as num?)?.toDouble(),
      avatarUserId: json['avatarUserId']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      lastKind: json['lastKind']?.toString() ?? 'text',
      lastSenderId: json['lastSenderId']?.toString(),
      lastOpenedAt: json['lastOpenedAt']?.toString(),
      muted: json['muted'] == true,
      memberIds: (json['memberIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
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

    final primaryMember = visibleMembers.isNotEmpty
        ? visibleMembers.first
        : (members.isNotEmpty ? members.first : null);
    final title = isGroup
        ? ((json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : 'Group')
        : (primaryMember == null ? 'Chat' : _memberLabel(primaryMember));
    final avatarUrl = isGroup || primaryMember == null
        ? null
        : (primaryMember['avatarUrl'] ?? primaryMember['avatar_url'])
            ?.toString()
            .trim();
    final avatarUserId =
        isGroup || primaryMember == null ? null : _memberId(primaryMember);
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
      avatarUserId: avatarUserId,
      avatarUrl: avatarUrl?.isNotEmpty == true ? avatarUrl : null,
      lastKind: lastKind,
      lastSenderId: lastSenderId,
      lastOpenedAt: lastOpenedAt,
      muted: json['muted'] == true,
      memberIds: memberIds.toList(growable: false),
    );
  }
}
