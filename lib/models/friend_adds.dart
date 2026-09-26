import 'package:pyrechat_flutter/models/friend.dart';

class FriendAddsBundle {
  const FriendAddsBundle({
    required this.incoming,
    required this.sent,
    required this.hidden,
    required this.deleted,
    required this.suggestions,
  });

  final List<PyreFriend> incoming;
  final List<PyreFriend> sent;
  final List<PyreFriend> hidden;
  final List<PyreFriend> deleted;
  final List<PyreFriend> suggestions;

  factory FriendAddsBundle.fromJson(Map<String, dynamic> json) {
    List<PyreFriend> parseList(String key) {
      final arr = json[key] as List<dynamic>? ?? [];
      return arr
          .map((e) => PyreFriend.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    return FriendAddsBundle(
      incoming: parseList('incoming'),
      sent: parseList('sent'),
      hidden: parseList('hidden'),
      deleted: parseList('deleted'),
      suggestions: parseList('suggestions'),
    );
  }
}
