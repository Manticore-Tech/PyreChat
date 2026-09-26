import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/capture_send_target.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/screens/chats/chat_thread_screen.dart';
import 'package:pyrechat_flutter/services/chat_order_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/chat_row.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';
import 'package:pyrechat_flutter/widgets/swipe_back_scope.dart';

enum _ChatFilter { all, groups, unopened }

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    required this.hub,
    required this.user,
    this.onGoCamera,
    this.client,
  });

  final PyreHub hub;
  final PyreUser user;
  final ValueChanged<CaptureSendTarget?>? onGoCamera;
  final PyreClient? client;

  @override
  State<ChatsScreen> createState() => ChatsScreenState();
}

class ChatsScreenState extends State<ChatsScreen>
    with AutomaticKeepAliveClientMixin {
  late final PyreClient _client;
  final _orderPrefs = ChatOrderPrefs();
  List<ChatPreview> _chats = [];
  Map<String, ChatPinPosition> _pinPositions = const {};
  bool _loading = true;
  int _loadGeneration = 0;
  String? _error;
  _ChatFilter _filter = _ChatFilter.all;
  late PyreHubStatus _hubStatus;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PyreClient();
    _hubStatus = widget.hub.status;
    widget.hub.addStatusListener(_onHubStatus);
    reload();
  }

  @override
  void dispose() {
    widget.hub.removeStatusListener(_onHubStatus);
    super.dispose();
  }

  void _onHubStatus(PyreHubStatus status) {
    if (!mounted || status == _hubStatus) return;
    setState(() => _hubStatus = status);
  }

  Future<void> reload({bool silent = false}) async {
    final generation = ++_loadGeneration;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final chats = await _client.chats();
      final pinPositions = await _orderPrefs.positionsFor(
        chats.map((chat) => chat.id),
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _chats = chats;
        _pinPositions = pinPositions;
        _loading = false;
        _error = null;
      });
    } on PyreApiException catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      if (!silent) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      if (!silent) {
        setState(() {
          _error = 'Could not load chats';
          _loading = false;
        });
      }
    }
  }

  List<ChatPreview> get _visibleChats {
    final filtered = switch (_filter) {
      _ChatFilter.all => List<ChatPreview>.from(_chats),
      _ChatFilter.groups =>
        _chats.where((c) => c.avatarKind == ChatAvatarKind.group).toList(),
      _ChatFilter.unopened => _chats.where((c) => c.unread > 0).toList(),
    };

    int rank(ChatPreview chat) {
      return switch (_pinPositions[chat.id] ?? ChatPinPosition.none) {
        ChatPinPosition.top => 0,
        ChatPinPosition.none => 1,
        ChatPinPosition.bottom => 2,
      };
    }

    filtered.sort((a, b) => rank(a).compareTo(rank(b)));
    return filtered;
  }

  ChatPinPosition _pinFor(ChatPreview chat) =>
      _pinPositions[chat.id] ?? ChatPinPosition.none;

  Future<void> _setPin(ChatPreview chat, ChatPinPosition position) async {
    await _orderPrefs.setPosition(chat.id, position);
    if (!mounted) return;
    setState(() {
      _pinPositions = {
        ..._pinPositions,
        chat.id: position,
      };
    });
  }

  int get _unopenedCount => _chats.where((c) => c.unread > 0).length;

  Future<void> _openAddFriends() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddFriendsScreen()),
    );
    if (mounted) await reload(silent: true);
  }

  CaptureSendTarget? _captureTargetFor(ChatPreview chat) {
    final recipients = chat.recipientIdsFor(widget.user.id);
    if (recipients.isEmpty) return null;
    return CaptureSendTarget(
      conversationId: chat.id,
      recipientIds: recipients,
      label: chat.title,
    );
  }

  Future<bool> _confirmClearChat(ChatPreview chat) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: PyreColors.paper,
            title: const Text(
              'Clear chat?',
              style: TextStyle(
                color: PyreColors.onPaper,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              'Clear your chat history with ${chat.title}?',
              style: const TextStyle(color: PyreColors.onPaperMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showChatOptions(ChatPreview chat) async {
    final currentPin = _pinFor(chat);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PyreColors.nightCardStrong,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        Widget tile({
          required IconData icon,
          required String title,
          required String value,
        }) {
          return ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: PyreColors.ember.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: PyreColors.emberGlow, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: PyreColors.nightText,
                fontWeight: FontWeight.w800,
              ),
            ),
            onTap: () => Navigator.pop(ctx, value),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: PyreColors.nightMuted.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PyreColors.nightText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (chat.muted)
                        const Text(
                          'Quiet',
                          style: TextStyle(
                            color: PyreColors.nightMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                tile(
                  icon: chat.muted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  title: chat.muted
                      ? 'Turn notifications on'
                      : 'Turn notifications off',
                  value: chat.muted ? 'unmute' : 'mute',
                ),
                tile(
                  icon: Icons.vertical_align_top_rounded,
                  title: currentPin == ChatPinPosition.top
                      ? 'Remove top pin'
                      : 'Pin to top',
                  value: currentPin == ChatPinPosition.top
                      ? 'unpin'
                      : 'pin_top',
                ),
                tile(
                  icon: Icons.vertical_align_bottom_rounded,
                  title: currentPin == ChatPinPosition.bottom
                      ? 'Remove bottom pin'
                      : 'Pin to bottom',
                  value: currentPin == ChatPinPosition.bottom
                      ? 'unpin'
                      : 'pin_bottom',
                ),
                const Divider(color: PyreColors.nightLine, height: 20),
                tile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Clear chat history',
                  value: 'clear',
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;

    if (action == 'pin_top') {
      await _setPin(chat, ChatPinPosition.top);
      return;
    }
    if (action == 'pin_bottom') {
      await _setPin(chat, ChatPinPosition.bottom);
      return;
    }
    if (action == 'unpin') {
      await _setPin(chat, ChatPinPosition.none);
      return;
    }

    if (action == 'clear' && !await _confirmClearChat(chat)) return;
    if (!mounted) return;

    try {
      if (action == 'mute') {
        await _client.muteChat(chat.id, muted: true);
      } else if (action == 'unmute') {
        await _client.muteChat(chat.id, muted: false);
      } else if (action == 'clear') {
        await _client.clearChat(chat.id);
      }
      if (mounted) await reload(silent: true);
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PyreNightBackdrop(
      mood: PyreNightMood.night,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChatsHeader(
            user: widget.user,
            onAddFriends: _openAddFriends,
            onGoCamera: () => widget.onGoCamera?.call(null),
          ),
          _FilterBar(
            filter: _filter,
            unopenedCount: _unopenedCount,
            onFilter: (f) => setState(() => _filter = f),
          ),
          _HubStatusStrip(status: _hubStatus),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _chats.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: PyreColors.emberDeep),
      );
    }
    if (_error != null && _chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PyreColors.nightText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final chats = _visibleChats;
    if (_chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No chats yet — add friends and send a Pyre from Camera.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PyreColors.nightMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    if (chats.isEmpty) {
      return Center(
        child: Text(
          'Nothing here yet',
          style: TextStyle(
            color: PyreColors.nightMuted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: PyreColors.emberGlow,
      backgroundColor: PyreColors.nightCardStrong,
      onRefresh: () => reload(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 118),
        itemCount: chats.length + 1,
        itemBuilder: (context, i) {
          if (i == chats.length) {
            return const _CaughtUpCard();
          }

          final chat = chats[i];
          final cameraTarget = _captureTargetFor(chat);
          return ChatRow(
            chat: chat,
            meId: widget.user.id,
            pinPosition: _pinFor(chat),
            onTap: () async {
              await Navigator.of(context).push(
                chatThreadRoute(
                  ChatThreadScreen(
                    chatId: chat.id,
                    hub: widget.hub,
                    title: chat.title,
                    me: widget.user,
                    onGoCamera: () => widget.onGoCamera?.call(cameraTarget),
                  ),
                ),
              );
              if (mounted) await reload(silent: true);
            },
            onLongPress: () => _showChatOptions(chat),
            onCameraTap: () => widget.onGoCamera?.call(cameraTarget),
          );
        },
      ),
    );
  }
}

class _HubStatusStrip extends StatelessWidget {
  const _HubStatusStrip({required this.status});

  final PyreHubStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == PyreHubStatus.connected) return const SizedBox.shrink();

    final label = switch (status) {
      PyreHubStatus.disconnected => 'Offline',
      PyreHubStatus.connecting => 'Connecting…',
      PyreHubStatus.reconnecting => 'Reconnecting…',
      PyreHubStatus.connected => '',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      color: Colors.black.withValues(alpha: 0.16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: PyreColors.onEmber,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChatsHeader extends StatelessWidget {
  const _ChatsHeader({
    required this.user,
    required this.onAddFriends,
    this.onGoCamera,
  });

  final PyreUser user;
  final VoidCallback onAddFriends;
  final VoidCallback? onGoCamera;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final initial =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.fromLTRB(18, top + 18, 18, 14),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              'Chats',
              style: TextStyle(
                color: PyreColors.onEmber,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                shadows: [
                  Shadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PyreColors.nightCardStrong,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: PyreColors.emberGlow,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    asset: PyreIcons.search,
                    onTap: onAddFriends,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconButton(
                    asset: PyreIcons.usersAdd,
                    onTap: onAddFriends,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    asset: PyreIcons.sendOutline,
                    onTap: onGoCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.asset, this.onTap});

  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.055),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.085),
            ),
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              PyreColors.onEmber,
              BlendMode.srcIn,
            ),
            child: PyreIcon(
              asset: asset,
              size: 22,
              opacity: onTap == null ? 0.35 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.unopenedCount,
    required this.onFilter,
  });

  final _ChatFilter filter;
  final int unopenedCount;
  final ValueChanged<_ChatFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.085),
        ),
        boxShadow: [
          BoxShadow(
            color: PyreColors.ink.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: 'All',
              selected: filter == _ChatFilter.all,
              onTap: () => onFilter(_ChatFilter.all),
            ),
          ),
          Expanded(
            child: _FilterChip(
              label: 'Groups',
              selected: filter == _ChatFilter.groups,
              onTap: () => onFilter(_ChatFilter.groups),
            ),
          ),
          Expanded(
            child: _FilterChip(
              label: 'Unopened',
              badge: unopenedCount > 0 ? '$unopenedCount' : null,
              selected: filter == _ChatFilter.unopened,
              onTap: () => onFilter(_ChatFilter.unopened),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? PyreColors.ember.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(21),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: PyreColors.ember.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? PyreColors.emberGlow
                          : PyreColors.nightMuted,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? PyreColors.emberHot
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: selected
                            ? PyreColors.nightText
                            : PyreColors.nightMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaughtUpCard extends StatelessWidget {
  const _CaughtUpCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 30, 12, 18),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PyreColors.ember.withValues(alpha: 0.10),
              border: Border.all(
                color: PyreColors.emberGlow.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: PyreColors.emberGlow,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You’re caught up',
            style: TextStyle(
              color: PyreColors.nightText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'No infinite feed. Come back when someone actually talks to you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PyreColors.nightMuted,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
