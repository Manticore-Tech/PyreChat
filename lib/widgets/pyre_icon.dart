import 'package:flutter/material.dart';

/// Individual icons cropped from `icon_sheet.png` — transparency preserved.
abstract final class PyreIcons {
  static const _base = 'assets/icons';

  // Tabs & brand
  static const flame = '$_base/flame.png';
  static const flamePlus = '$_base/flame_plus.png';
  static const chat = '$_base/chat.png';
  static const camera = '$_base/camera.png';
  static const profile = '$_base/profile.png';
  static const users = '$_base/users.png';
  static const usersAdd = '$_base/users_add.png';

  // Common chrome
  static const search = '$_base/search.png';
  static const sendOutline = '$_base/send_outline.png';
  static const settings = '$_base/settings.png';
  static const bell = '$_base/bell.png';
  static const bellMuted = '$_base/bell_muted.png';
  static const mail = '$_base/mail.png';
  static const send = '$_base/send.png';
  static const gallery = '$_base/gallery.png';
  static const video = '$_base/video.png';
  static const refresh = '$_base/refresh.png';
  static const mic = '$_base/mic.png';
  static const smile = '$_base/smile.png';
  static const sticker = '$_base/sticker.png';
  static const phone = '$_base/phone.png';
  static const arrowLeft = '$_base/arrow_left.png';
  static const more = '$_base/more.png';
}

class PyreIcon extends StatelessWidget {
  const PyreIcon({
    super.key,
    required this.asset,
    required this.size,
    this.opacity = 1,
  });

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        isAntiAlias: true,
      ),
    );
  }
}
