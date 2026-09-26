import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

class PyreAvatar extends StatelessWidget {
  const PyreAvatar({
    super.key,
    required this.user,
    this.size = 52,
    this.showRing = false,
  });

  final PyreUser user;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.username.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    final fallback = ColoredBox(
      color: PyreColors.ink,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: PyreColors.paper,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    final avatar = ClipOval(
      child: user.avatarUrl == null || user.avatarUrl!.isEmpty
          ? fallback
          : Image.network(
              user.avatarUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => fallback,
            ),
    );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(showRing ? 2.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: showRing
            ? const LinearGradient(
                colors: [PyreColors.sunset, PyreColors.emberDeep],
              )
            : null,
      ),
      child: avatar,
    );
  }
}
