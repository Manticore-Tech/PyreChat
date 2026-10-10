import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/capture_send_target.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/screens/chats/chat_thread_screen.dart';
import 'package:pyrechat_flutter/screens/chats/pyre_rcs_screen.dart';
import 'package:pyrechat_flutter/services/chat_cache.dart';
import 'package:pyrechat_flutter/services/chat_order_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/services/pyre_notifications.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/chat_row.dart';
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
  final _cache = ChatCache.instance;
  List<ChatPreview> _chats = [];
  Map<String, ChatPinPosition> _pinPositions = const {};
  bool _loading = true;
  int _loadGeneration = 0;
  String? _error;
  _ChatFilter _filter = _ChatFilter.all;
  String? _activeChatId;
  String? _pendingOpenChatId;
  bool _pendingOpenFromNotification = false;
  bool _networkUnavailable = false;
  bool _remoteRefreshSucceeded = false;
  late PyreHubStatus _hubStatus;
  final Map<String, Map<String, String>> _typingByChat = {};
  final Map<String, Timer> _typingExpiry = {};

  @override
  bool get wantKeepAlive => true;

  String? get activeChatId => _activeChatId;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PyreClient();
    _hubStatus = widget.hub.status;
    widget.hub.addListener(_onHubEvent);
    widget.hub.addStatusListener(_onHubStatus);
    unawaited(_restoreCacheAndRefresh());
  }

  @override
  void dispose() {
    widget.hub.removeListener(_onHubEvent);
    widget.hub.removeStatusListener(_onHubStatus);
    for (final timer in _typingExpiry.values) {
      timer.cancel();
    }
    _typingExpiry.clear();
    super.dispose();
  }

  void _onHubStatus(PyreHubStatus status) {
    if (!mounted || status == _hubStatus) return;
    setState(() => _hubStatus = status);
  }

  void _onHubEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    final chatId = (event['conversationId'] ??
            event['chatId'] ??
            event['conversation_id'])
        ?.toString()
        .trim();
    if (chatId == null || chatId.isEmpty) return;

    if (type == 'typing') {
      final from = event['from']?.toString().trim();
      if (from == null || from.isEmpty || from == widget.user.id) return;
      final key = '$chatId:$from';
      _typingExpiry.remove(key)?.cancel();
      final active = event['active'] != false;
      if (!active) {
        final current = _typingByChat[chatId];
        if (current != null) {
          current.remove(from);
          if (current.isEmpty) _typingByChat.remove(chatId);
          if (mounted) setState(() {});
        }
        return;
      }

      final rawName = event['fromName']?.toString().trim();
      final name = rawName == null || rawName.isEmpty ? 'Someone' : rawName;
      _typingByChat.putIfAbsent(chatId, () => <String, String>{})[from] = name;
      _typingExpiry[key] = Timer(const Duration(milliseconds: 4000), () {
        final current = _typingByChat[chatId];
        if (current == null) return;
        current.remove(from);
        if (current.isEmpty) _typingByChat.remove(chatId);
        _typingExpiry.remove(key);
        if (mounted) setState(() {});
      });
      if (mounted) setState(() {});
      return;
    }

    if (type == 'chat') {
      final current = _typingByChat.remove(chatId);
      if (current != null) {
        for (final from in current.keys) {
          _typingExpiry.remove('$chatId:$from')?.cancel();
        }
        if (mounted) setState(() {});
      }
    }
  }

  String? _typingLabelFor(ChatPreview chat) {
    final names = _typingByChat[chat.id]?.values.toList() ?? const <String>[];
    if (names.isEmpty) return null;

    String first(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 'Someone';
      return trimmed.split(RegExp(r'\s+')).first;
    }

    if (names.length == 1) return '${first(names.first)} is typing…';
    if (names.length == 2) {
      return '${first(names[0])} and ${first(names[1])} are typing…';
    }
    return '${names.length} people are typing…';
  }

  Future<void> _restoreCacheAndRefresh() async {
    final cachedFuture = _cache.readChats(widget.user.id);
    unawaited(reload(silent: true));

    final cached = await cachedFuture;
    if (!mounted || _remoteRefreshSucceeded || cached == null) return;

    final pinPositions = await _orderPrefs.positionsFor(
      cached.map((chat) => chat.id),
    );
    if (!mounted || _remoteRefreshSucceeded) return;
    setState(() {
      _chats = cached;
      _pinPositions = pinPositions;
      _loading = false;
      _error = null;
    });
    _maybeOpenPendingConversation();
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
        _networkUnavailable = false;
        _remoteRefreshSucceeded = true;
      });
      unawaited(_cache.writeChats(widget.user.id, chats));
      _maybeOpenPendingConversation();
    } on PyreApiException catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      final offline = e.statusCode == null;
      _remoteRefreshSucceeded = false;
      setState(() {
        _networkUnavailable = offline || _networkUnavailable;
        _loading = false;
        if (!silent && _chats.isEmpty) {
          _error = e.message;
        }
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _remoteRefreshSucceeded = false;
      setState(() {
        _networkUnavailable = true;
        _loading = false;
        if (!silent && _chats.isEmpty) {
          _error = 'Could not load chats';
        }
      });
    }
  }

  ChatPreview? _chatForId(String chatId) {
    for (final chat in _chats) {
      if (chat.id == chatId) return chat;
    }
    return null;
  }

  Future<void> openConversation(
    String chatId, {
    bool fromNotification = false,
  }) async {
    final normalized = chatId.trim();
    if (normalized.isEmpty || _activeChatId == normalized) return;
    final chat = _chatForId(normalized);
    if (chat == null) {
      _pendingOpenChatId = normalized;
      _pendingOpenFromNotification =
          _pendingOpenFromNotification || fromNotification;
      return;
    }
    _pendingOpenChatId = null;
    final notificationOpen =
        _pendingOpenFromNotification || fromNotification;
    _pendingOpenFromNotification = false;
    await _openChat(chat, fromNotification: notificationOpen);
  }

  void _maybeOpenPendingConversation() {
    final chatId = _pendingOpenChatId;
    if (chatId == null || _chatForId(chatId) == null || !mounted) return;
    final fromNotification = _pendingOpenFromNotification;
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(
          openConversation(
            chatId,
            fromNotification: fromNotification,
          ),
        );
      }
    });
  }

  Future<void> _openChat(
    ChatPreview chat, {
    bool fromNotification = false,
  }) async {
    final cameraTarget = _captureTargetFor(chat);
    if (mounted) setState(() => _activeChatId = chat.id);
    unawaited(
      PyreNotifications.instance.setContext(
        foreground: true,
        activeConversationId: chat.id,
      ),
    );
    await Navigator.of(context).push(
      chatThreadRoute(
        ChatThreadScreen(
          chatId: chat.id,
          hub: widget.hub,
          title: chat.title,
          me: widget.user,
          peerUserId: chat.avatarUserId,
          requirePrivateText: chat.requiresPrivateText,
          openedFromNotification: fromNotification,
          onGoCamera: () => widget.onGoCamera?.call(cameraTarget),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _activeChatId = null);
    unawaited(
      PyreNotifications.instance.setContext(
        foreground: true,
        activeConversationId: null,
      ),
    );
    await reload(silent: true);
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

    // Preserve server recency within each pin bucket. Dart's List.sort is
    // not stable, so sorting only by pin rank can shuffle equally ranked chats.
    final originalPositions = <String, int>{
      for (var index = 0; index < filtered.length; index++)
        filtered[index].id: index,
    };
    filtered.sort((a, b) {
      final rankComparison = rank(a).compareTo(rank(b));
      if (rankComparison != 0) return rankComparison;
      return originalPositions[a.id]!.compareTo(originalPositions[b.id]!);
    });
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

  Future<void> _openRcs() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PyreRcsInboxScreen(user: widget.user)),
    );
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
        final accent = Theme.of(ctx).colorScheme.primary;
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
                color: accent.withValues(alpha: 0.12),
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
        await _cache.deleteThread(widget.user.id, chat.id);
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
      mood: PyreSurfaceMood.chats,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChatsHeader(
            user: widget.user,
            onAddFriends: _openAddFriends,
            onRcs: _openRcs,
            onGoCamera: () => widget.onGoCamera?.call(null),
          ),
          _FilterBar(
            filter: _filter,
            unopenedCount: _unopenedCount,
            onFilter: (f) => setState(() => _filter = f),
          ),
          _ChatsConnectionStatus(
            status: _hubStatus,
            networkUnavailable: _networkUnavailable,
            showingCachedChats: _networkUnavailable && _chats.isNotEmpty,
          ),
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
    if (_networkUnavailable && _chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You are offline. No saved chats are available on this device yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
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
    if (_error != null && _chats.isEmpty) {
      final message = _error!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
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
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 106),
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
            typingLabel: _typingLabelFor(chat),
            onTap: () => _openChat(chat),
            onLongPress: () => _showChatOptions(chat),
            onCameraTap: () => widget.onGoCamera?.call(cameraTarget),
          );
        },
      ),
    );
  }
}

class _ChatsConnectionStatus extends StatelessWidget {
  const _ChatsConnectionStatus({
    required this.status,
    required this.networkUnavailable,
    required this.showingCachedChats,
  });

  final PyreHubStatus status;
  final bool networkUnavailable;
  final bool showingCachedChats;

  @override
  Widget build(BuildContext context) {
    if (!networkUnavailable && status == PyreHubStatus.connected) {
      return const SizedBox.shrink();
    }

    final label = networkUnavailable
        ? showingCachedChats
            ? 'You are offline — showing saved chats'
            : 'You are offline'
        : 'Reconnecting…';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      color: const Color(0xFF111111),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFB5B5BA),
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
    required this.onRcs,
    this.onGoCamera,
  });

  final PyreUser user;
  final VoidCallback onAddFriends;
  final VoidCallback onRcs;
  final VoidCallback? onGoCamera;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final initial =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 14, 12, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: PyreColors.emberGlow,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Chats',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: PyreColors.nightText,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.9,
                height: 1,
              ),
            ),
          ),
          _HeaderIconButton(
            icon: Icons.forum_outlined,
            accented: true,
            tooltip: 'RCS messages',
            onTap: onRcs,
          ),
          const SizedBox(width: 2),
          _HeaderIconButton(
            icon: Icons.person_add_alt_1_rounded,
            accented: true,
            tooltip: 'Add friends',
            onTap: onAddFriends,
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            icon: Icons.photo_camera_outlined,
            tooltip: 'Open camera',
            onTap: onGoCamera,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    this.onTap,
    this.accented = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool accented;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final enabled = onTap != null;
    final button = Material(
      color: Colors.transparent,
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
              color: accented
                  ? accent.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: enabled
                ? (accented ? accent : PyreColors.nightText)
                : PyreColors.nightMuted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
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
      height: 44,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
        ),
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
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.075)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
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