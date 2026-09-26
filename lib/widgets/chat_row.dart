import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/services/chat_order_prefs.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';

class ChatRow extends StatelessWidget {
  const ChatRow({
    super.key,
    required this.chat,
    required this.meId,
    this.onTap,
    this.onLongPress,
    this.onCameraTap,
    this.pinPosition = ChatPinPosition.none,
  });

  final ChatPreview chat;
  final String meId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCameraTap;
  final ChatPinPosition pinPosition;

  static const _snapRed = Color(0xFFFF6557);

  bool get _mine => chat.lastFromMe(meId);

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel();
    final time = chat.timeLabel;
    final subtitle = time.isEmpty ? status : '$status · $time';
    final snapLine = chat.lastKind == 'snap';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: PyreColors.nightCard,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(12, 9, 9, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: chat.unread > 0
                    ? PyreColors.ember.withValues(alpha: 0.34)
                    : Colors.white.withValues(alpha: 0.055),
              ),
              boxShadow: [
                if (chat.unread > 0)
                  BoxShadow(
                    color: PyreColors.ember.withValues(alpha: 0.08),
                    blurRadius: 18,
                    spreadRadius: -3,
                  ),
              ],
            ),
            child: Row(
              children: [
                _Avatar(chat: chat),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PyreColors.nightText,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.25,
                                height: 1.08,
                              ),
                            ),
                          ),
                          if (pinPosition != ChatPinPosition.none) ...[
                            const SizedBox(width: 5),
                            Icon(
                              pinPosition == ChatPinPosition.top
                                  ? Icons.push_pin_rounded
                                  : Icons.vertical_align_bottom_rounded,
                              size: 14,
                              color: PyreColors.emberGlow,
                            ),
                          ],
                          if (chat.muted) ...[
                            const SizedBox(width: 5),
                            const ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                PyreColors.nightMuted,
                                BlendMode.srcIn,
                              ),
                              child: PyreIcon(
                                asset: PyreIcons.bellMuted,
                                size: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (snapLine) ...[
                            _StatusGlyph(
                              kind: _glyphKind(),
                              color: chat.unread > 0 || !_mine
                                  ? _snapRed
                                  : PyreColors.emberGlow,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: chat.unread > 0
                                    ? const Color(0xFFE9E3DE)
                                    : PyreColors.nightMuted,
                                fontSize: 13,
                                fontWeight: chat.unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (chat.unread > 0) ...[
                  const SizedBox(width: 7),
                  _UnreadBadge(count: chat.unread),
                ],
                const SizedBox(width: 7),
                Material(
                  color: Colors.white.withValues(alpha: 0.055),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onCameraTap ?? onTap,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            PyreColors.nightText,
                            BlendMode.srcIn,
                          ),
                          child: PyreIcon(
                            asset: PyreIcons.camera,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _GlyphKind _glyphKind() {
    if (chat.unread > 0) return _GlyphKind.delivered;
    if (_mine && chat.lastOpenedAt != null) return _GlyphKind.opened;
    if (_mine) return _GlyphKind.delivered;
    return _GlyphKind.opened;
  }

  String _statusLabel() {
    if (chat.unread > 0) return 'New Snap';
    if (chat.lastKind == 'snap') {
      if (_mine) {
        return chat.lastOpenedAt != null ? 'Opened' : 'Delivered';
      }
      return 'Opened';
    }
    if (_mine) return 'Delivered';
    return chat.preview;
  }
}

enum _GlyphKind { opened, delivered }

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.kind, required this.color});

  final _GlyphKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: switch (kind) {
        _GlyphKind.opened => Icon(Icons.reply_outlined, size: 14, color: color),
        _GlyphKind.delivered => Transform.flip(
            flipX: true,
            child: Icon(Icons.reply, size: 14, color: color),
          ),
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.chat});

  final ChatPreview chat;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        switch (chat.avatarKind) {
          ChatAvatarKind.person => Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    PyreColors.emberGlow.withValues(alpha: 0.95),
                    const Color(0xFF5440A6),
                  ],
                ),
              ),
              child: CircleAvatar(
              radius: 23,
              backgroundColor: HSLColor.fromAHSL(
                1,
                chat.avatarHue ?? 28,
                0.42,
                0.52,
              ).toColor(),
              child: Text(
                chat.avatarInitials ?? chat.title.characters.first,
                style: const TextStyle(
                  color: PyreColors.paper,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ),
          ChatAvatarKind.group => _IconAvatar(icon: PyreIcons.users),
          ChatAvatarKind.channel => _IconAvatar(
              child: Text(
                '#',
                style: TextStyle(
                  color: PyreColors.paper,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
        },
        if (chat.unread > 0)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: PyreColors.nightRaised,
                shape: BoxShape.circle,
                border: Border.all(color: PyreColors.paper, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _IconAvatar extends StatelessWidget {
  const _IconAvatar({this.icon, this.child})
      : assert(icon != null || child != null);

  final String? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: PyreColors.ember,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child ??
          ColorFiltered(
            colorFilter: const ColorFilter.mode(PyreColors.paper, BlendMode.srcIn),
            child: PyreIcon(asset: icon!, size: 22),
          ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PyreColors.emberHot,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: PyreColors.paper,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
