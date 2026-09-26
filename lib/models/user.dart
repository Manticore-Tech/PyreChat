class PyreUser {
  const PyreUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory PyreUser.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final username = json['username']?.toString() ?? '';
    final rawDisplayName = json['displayName'] ?? json['display_name'];
    final displayName = rawDisplayName?.toString().trim();
    final rawAvatar = json['avatarUrl'] ??
        json['avatar_url'] ??
        json['bitmojiAvatar'] ??
        json['bitmoji_avatar'];
    final avatarUrl = rawAvatar?.toString().trim();

    return PyreUser(
      id: id,
      username: username,
      displayName: displayName?.isNotEmpty == true ? displayName! : username,
      avatarUrl: avatarUrl?.isNotEmpty == true ? avatarUrl : null,
    );
  }
}
