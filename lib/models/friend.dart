class PyreFriend {
  const PyreFriend({
    required this.id,
    required this.username,
    required this.displayName,
    this.status,
  });

  final String id;
  final String username;
  final String displayName;
  final String? status;

  factory PyreFriend.fromJson(Map<String, dynamic> json) {
    return PyreFriend(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: (json['display_name'] as String?) ??
          (json['displayName'] as String?) ??
          json['username'] as String,
      status: json['status'] as String?,
    );
  }
}
