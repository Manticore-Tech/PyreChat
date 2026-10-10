import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/services/profile_photo_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
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

    final photoPrefs = ProfilePhotoPrefs.instance;

    return AnimatedBuilder(
      animation: photoPrefs,
      builder: (context, _) {
        final localBytes =
            photoPrefs.userId == user.id ? photoPrefs.bytes : null;
        final avatar = ClipOval(
          child: localBytes != null
              ? Image.memory(
                  localBytes,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? fallback
                  : _RemoteAvatarImage(
                      url: user.avatarUrl!,
                      size: size,
                      fallback: fallback,
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
      },
    );
  }
}


class _RemoteAvatarImage extends StatefulWidget {
  const _RemoteAvatarImage({
    required this.url,
    required this.size,
    required this.fallback,
  });

  final String url;
  final double size;
  final Widget fallback;

  @override
  State<_RemoteAvatarImage> createState() => _RemoteAvatarImageState();
}

class _RemoteAvatarImageState extends State<_RemoteAvatarImage> {
  late final Future<String?> _token = SessionStore().token;

  @override
  Widget build(BuildContext context) {
    final api = PyreApi();
    final raw = widget.url.trim();
    final parsed = Uri.tryParse(raw);
    final apiUri = Uri.parse(api.origin);
    final isApiUrl = parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme == apiUri.scheme &&
            parsed.host == apiUri.host &&
            parsed.port == apiUri.port);
    final resolved = parsed != null && parsed.hasScheme
        ? raw
        : '${api.origin}${raw.startsWith('/') ? '' : '/'}$raw';

    if (!isApiUrl) {
      return Image.network(
        resolved,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    }

    return FutureBuilder<String?>(
      future: _token,
      builder: (context, snapshot) {
        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return widget.fallback;
        }
        return Image.network(
          resolved,
          headers: {'Authorization': 'Bearer $token'},
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }
}
