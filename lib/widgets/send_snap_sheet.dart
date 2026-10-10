import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_media_saver.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_video_view.dart';

Future<bool> showSendSnapSheet({
  required BuildContext context,
  required Uint8List imageBytes,
  String? imagePath,
  String mime = 'image/jpeg',
  String? conversationId,
  List<String>? recipientIds,
  String? recipientLabel,
}) {
  return showSendSnapMediaSheet(
    context: context,
    mediaBytes: imageBytes,
    mediaKind: 'photo',
    mime: mime,
    mediaPath: imagePath,
    conversationId: conversationId,
    recipientIds: recipientIds,
    recipientLabel: recipientLabel,
  );
}

Future<bool> showSendSnapVideoSheet({
  required BuildContext context,
  required Uint8List videoBytes,
  String? videoPath,
  String mime = 'video/mp4',
  String? conversationId,
  List<String>? recipientIds,
  String? recipientLabel,
}) {
  return showSendSnapMediaSheet(
    context: context,
    mediaBytes: videoBytes,
    mediaKind: 'video',
    mime: mime,
    mediaPath: videoPath,
    conversationId: conversationId,
    recipientIds: recipientIds,
    recipientLabel: recipientLabel,
  );
}

Future<bool> showSendSnapMediaSheet({
  required BuildContext context,
  required Uint8List mediaBytes,
  required String mediaKind,
  required String mime,
  String? mediaPath,
  String? conversationId,
  List<String>? recipientIds,
  String? recipientLabel,
}) async {
  final sent = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => _SendSnapReviewPage(
        mediaBytes: mediaBytes,
        mediaKind: mediaKind,
        mime: mime,
        mediaPath: mediaPath,
        conversationId: conversationId,
        recipientIds: recipientIds,
        recipientLabel: recipientLabel,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      ),
    ),
  );
  return sent == true;
}

class _SendSnapReviewPage extends StatefulWidget {
  const _SendSnapReviewPage({
    required this.mediaBytes,
    required this.mediaKind,
    required this.mime,
    this.mediaPath,
    this.conversationId,
    this.recipientIds,
    this.recipientLabel,
  });

  final Uint8List mediaBytes;
  final String mediaKind;
  final String mime;
  final String? mediaPath;
  final String? conversationId;
  final List<String>? recipientIds;
  final String? recipientLabel;

  @override
  State<_SendSnapReviewPage> createState() => _SendSnapReviewPageState();
}

class _SendSnapReviewPageState extends State<_SendSnapReviewPage> {
  final _client = PyreClient();
  final _caption = TextEditingController();
  final _captionFocus = FocusNode();
  final _selected = <String>{};

  List<PyreFriend> _friends = const [];
  bool _friendsLoaded = false;
  bool _friendsLoading = false;
  bool _sending = false;
  bool _saving = false;
  bool _saved = false;
  bool _captionEditing = false;
  bool _useConversationTarget = false;
  String? _friendsError;

  Set<String> get _initialRecipients =>
      (widget.recipientIds ?? const <String>[]).toSet();

  @override
  void initState() {
    super.initState();
    _selected.addAll(_initialRecipients);
    _useConversationTarget =
        widget.conversationId?.isNotEmpty == true && _selected.isNotEmpty;

    if (!_useConversationTarget) {
      _ensureFriendsLoaded();
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  Future<void> _ensureFriendsLoaded() async {
    if (_friendsLoaded || _friendsLoading) return;
    setState(() {
      _friendsLoading = true;
      _friendsError = null;
    });

    try {
      final friends = await _client.friends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _friendsLoaded = true;
        _friendsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendsError = 'Could not load friends';
        _friendsLoading = false;
      });
    }
  }

  bool _matchesInitialRecipients(Set<String> value) {
    final initial = _initialRecipients;
    return value.length == initial.length &&
        value.every(initial.contains);
  }

  Future<void> _openRecipientPicker() async {
    await _ensureFriendsLoaded();
    if (!mounted) return;

    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101419),
      barrierColor: Colors.black.withValues(alpha: 0.52),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final draft = <String>{..._selected};
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottom = MediaQuery.paddingOf(context).bottom;
            return SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Send To',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(draft),
                            child: Text(
                              draft.isEmpty ? 'Done' : 'Done · ${draft.length}',
                              style: const TextStyle(
                                color: PyreColors.emberGlow,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                    if (_friendsLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: PyreColors.emberGlow,
                          ),
                        ),
                      )
                    else if (_friendsError != null)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _friendsError!,
                                  style: const TextStyle(
                                    color: PyreColors.nightMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(sheetContext).pop();
                                    await _ensureFriendsLoaded();
                                    if (mounted) _openRecipientPicker();
                                  },
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (_friends.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Add friends first to send a Pyre.',
                            style: TextStyle(
                              color: PyreColors.nightMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 14),
                          itemCount: _friends.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 68,
                            color: Colors.white.withValues(alpha: 0.055),
                          ),
                          itemBuilder: (_, i) {
                            final friend = _friends[i];
                            final selected = draft.contains(friend.id);
                            return ListTile(
                              onTap: () {
                                setSheetState(() {
                                  if (selected) {
                                    draft.remove(friend.id);
                                  } else {
                                    draft.add(friend.id);
                                  }
                                });
                              },
                              leading: _FriendAvatar(friend: friend),
                              title: Text(
                                friend.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '@${friend.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: PyreColors.nightMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? PyreColors.emberGlow
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? PyreColors.emberGlow
                                        : Colors.white.withValues(alpha: 0.28),
                                    width: 2,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Colors.black,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || picked == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(picked);
      _useConversationTarget =
          widget.conversationId?.isNotEmpty == true &&
          _matchesInitialRecipients(picked);
    });
  }

  void _editCaption() {
    setState(() => _captionEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captionFocus.requestFocus();
    });
  }

  void _finishCaption() {
    _captionFocus.unfocus();
    setState(() => _captionEditing = false);
  }

  Future<void> _saveToDevice() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    try {
      final uri = await PyreMediaSaver.save(
        kind: widget.mediaKind,
        mime: widget.mime,
        path: widget.mediaPath,
        bytes: widget.mediaPath?.isNotEmpty == true ? null : widget.mediaBytes,
      );
      if (!mounted) return;
      if (uri == null || uri.isEmpty) {
        throw PlatformException(
          code: 'media_save_failed',
          message: 'Could not save media to device',
        );
      }
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.mediaKind == 'video'
                ? 'Saved to Movies/PyreChat'
                : 'Saved to Pictures/PyreChat',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving to device is unavailable on this platform.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Could not save to device'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save to device. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _send() async {
    if (_sending) return;

    if (_selected.isEmpty) {
      await _openRecipientPicker();
      if (!mounted || _selected.isEmpty) return;
    }

    setState(() => _sending = true);
    try {
      final mediaKey = await _client.uploadMedia(
        widget.mediaBytes,
        mime: widget.mime,
      );
      await _client.sendSnap(
        mediaKey: mediaKey,
        recipientIds: _selected.toList(growable: false),
        kind: widget.mediaKind,
        caption: _caption.text.trim(),
        conversationId:
            _useConversationTarget ? widget.conversationId : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send Pyre')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _sendLabel() {
    if (_sending) return 'Sending…';

    if (_useConversationTarget) {
      final label = widget.recipientLabel?.trim();
      return label?.isNotEmpty == true ? label! : 'Send';
    }

    if (_selected.isEmpty) return 'Send To';

    if (_selected.length == 1) {
      for (final friend in _friends) {
        if (_selected.contains(friend.id)) return friend.displayName;
      }
    }

    return 'Send ${_selected.length}';
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final captionText = _caption.text.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'pyre-captured-media',
            child: widget.mediaKind == 'video'
                ? _VideoCapturePreview(path: widget.mediaPath)
                : Image.memory(
                    widget.mediaBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x7A000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xB9000000),
                  ],
                  stops: [0, 0.20, 0.62, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Align(
                alignment: Alignment.topLeft,
                child: _OverlayCircleButton(
                  icon: Icons.close_rounded,
                  semanticLabel: 'Close Pyre composer',
                  onTap: _sending
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Align(
                alignment: Alignment.topRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OverlayCircleButton(
                      icon: Icons.text_fields_rounded,
                      semanticLabel:
                          captionText.isEmpty ? 'Add caption' : 'Edit caption',
                      active: _captionEditing || captionText.isNotEmpty,
                      onTap: _sending ? null : _editCaption,
                    ),
                    const SizedBox(height: 10),
                    _OverlayCircleButton(
                      icon: Icons.people_alt_outlined,
                      semanticLabel: 'Choose recipients',
                      active: !_useConversationTarget && _selected.isNotEmpty,
                      onTap: _sending ? null : _openRecipientPicker,
                    ),
                    const SizedBox(height: 10),
                    _OverlayCircleButton(
                      icon: _saved
                          ? Icons.download_done_rounded
                          : Icons.download_rounded,
                      semanticLabel: _saved ? 'Saved to device' : 'Save to device',
                      active: _saved,
                      onTap: _sending || _saving || _saved ? null : _saveToDevice,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_captionEditing || captionText.isNotEmpty)
            Align(
              alignment: const Alignment(0, -0.05),
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.48),
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: _caption,
                  focusNode: _captionFocus,
                  autofocus: _captionEditing,
                  enabled: !_sending,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  maxLines: 3,
                  minLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: _captionEditing ? 'Add a caption' : null,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _finishCaption(),
                  onTapOutside: (_) => _finishCaption(),
                ),
              ),
            ),
          if (keyboard == 0)
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  color: const Color(0xE60A0D10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BottomPill(
                          icon: Icons.group_add_outlined,
                          label: 'More Friends',
                          onTap: _sending ? null : _openRecipientPicker,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BottomPill(
                          icon: Icons.send_rounded,
                          label: _sendLabel(),
                          primary: true,
                          busy: _sending,
                          onTap: _sending ? null : _send,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoCapturePreview extends StatelessWidget {
  const _VideoCapturePreview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final videoPath = path?.trim();
    if (videoPath != null && videoPath.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PyreVideoView(
            path: videoPath,
            fallback: const ColoredBox(color: Colors.black),
          ),
          const IgnorePointer(
            child: Align(
              alignment: Alignment(0, 0.76),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x78000000),
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    'Tap video to pause or play',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_fill_rounded,
              color: PyreColors.emberGlow,
              size: 72,
            ),
            SizedBox(height: 14),
            Text(
              'Video ready to send',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Preview playback is coming next.',
              style: TextStyle(
                color: PyreColors.nightMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayCircleButton extends StatelessWidget {
  const _OverlayCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? PyreColors.emberGlow
          : Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            semanticLabel: semanticLabel,
            color: active ? Colors.black : Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _BottomPill extends StatelessWidget {
  const _BottomPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final background = primary
        ? Colors.white
        : Colors.white.withValues(alpha: 0.14);
    final foreground = primary ? Colors.black : Colors.white;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: foreground,
                    ),
                  )
                else
                  Icon(icon, size: 22, color: foreground),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
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
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend});

  final PyreFriend friend;

  @override
  Widget build(BuildContext context) {
    final avatar = friend.avatarUrl?.trim();
    final initial = friend.displayName.trim().isEmpty
        ? '?'
        : friend.displayName.trim().characters.first.toUpperCase();

    return CircleAvatar(
      radius: 23,
      backgroundColor: PyreColors.ember.withValues(alpha: 0.28),
      backgroundImage:
          avatar?.isNotEmpty == true ? NetworkImage(avatar!) : null,
      child: avatar?.isNotEmpty == true
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}
