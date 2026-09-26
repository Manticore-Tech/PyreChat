import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/chat_draft_store.dart';
import 'package:pyrechat_flutter/services/chat_message_merge.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/screens/chats/snap_viewer_screen.dart';
import 'package:pyrechat_flutter/screens/pyre/friend_pyre_screen.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';
import 'package:pyrechat_flutter/widgets/swipe_back_scope.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.chatId,
    required this.hub,
    required this.title,
    required this.me,
    this.onGoCamera,
    this.client,
  });

  final String chatId;
  final PyreHub hub;
  final String title;
  final PyreUser me;
  final VoidCallback? onGoCamera;
  final PyreClient? client;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  static const _chatInk = PyreColors.night;

  late final PyreClient _client;
  final _drafts = ChatDraftStore.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _followBottom = true;
  int _loadGeneration = 0;
  String? _error;
  Timer? _liveReloadDebounce;
  late PyreHubStatus _hubStatus;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PyreClient();
    _input.text = _drafts.draftFor(widget.chatId);
    _input.addListener(_onInputChanged);
    _scroll.addListener(_onScroll);
    _hubStatus = widget.hub.status;
    widget.hub.addListener(_onHubEvent);
    widget.hub.addStatusListener(_onHubStatus);
    _load();
  }

  @override
  void dispose() {
    widget.hub.removeListener(_onHubEvent);
    widget.hub.removeStatusListener(_onHubStatus);
    _liveReloadDebounce?.cancel();
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    _drafts.setDraft(widget.chatId, _input.text);
    if (mounted) setState(() {});
  }

  void _onHubStatus(PyreHubStatus status) {
    if (!mounted || status == _hubStatus) return;
    setState(() => _hubStatus = status);
  }

  void _onHubEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final kind = event['kind'] as String?;
    if (type != 'chat' &&
        type != 'snap' &&
        type != 'notification' &&
        kind != 'snap') {
      return;
    }

    final eventChatId = (event['chatId'] ??
            event['conversationId'] ??
            event['conversation_id'])
        ?.toString();
    if (eventChatId != null &&
        eventChatId.isNotEmpty &&
        eventChatId != widget.chatId) {
      return;
    }

    _liveReloadDebounce?.cancel();
    _liveReloadDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _load(silent: true);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final dist = position.maxScrollExtent - position.pixels;
    _followBottom = dist < 96;
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_loadGeneration;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final messages = await _client.messages(widget.chatId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _messages = mergeThreadMessages(
          remote: messages,
          current: _messages,
        );
        _loading = false;
        _error = null;
      });
      if (_followBottom) _pinToLatest();
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
          _error = 'Could not load messages';
          _loading = false;
        });
      }
    }
  }

  void _pinToLatest() {
    void jump() {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      final max = position.maxScrollExtent;
      if (position.pixels != max) {
        _scroll.jumpTo(max);
      }
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      jump();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) jump();
      });
    });
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) jump();
    });
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (mounted) jump();
    });
  }

  List<List<ChatMessage>> _groupMessages(List<ChatMessage> msgs) {
    final out = <List<ChatMessage>>[];
    for (final m in msgs) {
      final lane = m.isSnap ? 'snap' : 'chat';
      if (out.isNotEmpty &&
          out.last.first.senderId == m.senderId &&
          (out.last.first.isSnap ? 'snap' : 'chat') == lane) {
        out.last.add(m);
      } else {
        out.add([m]);
      }
    }
    return out;
  }

  Future<void> _openSnap(ChatMessage message) async {
    final mine = message.senderId == widget.me.id;
    if (mine) {
      await openSnapViewer(context, snapId: message.id, markViewed: false);
      return;
    }
    if (message.isUnopenedFor(widget.me.id)) {
      final viewed = await openSnapViewer(
        context,
        snapId: message.id,
        markViewed: true,
      );
      if (viewed == true && mounted) await _load(silent: true);
      return;
    }
    await openSnapViewer(context, snapId: message.id, markViewed: false);
    if (mounted) await _load(silent: true);
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Friend';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  void _openCamera() {
    final goCamera = widget.onGoCamera;
    Navigator.of(context).pop();
    if (goCamera != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => goCamera());
    }
  }

  Future<void> _openFriendPyre() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendPyreScreen(
          displayName: widget.title,
          seed: widget.chatId.hashCode,
          onLeavePhoto: widget.onGoCamera == null ? null : _openCamera,
        ),
      ),
    );
  }

  void _showSendFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Not sent — $message')),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final temp = ChatMessage(
      id: 'tmp-${DateTime.now().microsecondsSinceEpoch}',
      senderId: widget.me.id,
      kind: 'text',
      body: text,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      displayName: widget.me.displayName,
      username: widget.me.username,
      deliveryState: ChatDeliveryState.sending,
      localEcho: true,
    );

    setState(() {
      _sending = true;
      _messages = [..._messages, temp];
      _followBottom = true;
    });
    _input.clear();
    _pinToLatest();

    await _deliver(temp);
  }

  Future<void> _retryFailed(ChatMessage message) async {
    if (_sending || message.deliveryState != ChatDeliveryState.failed) return;

    final retry = message.copyWith(deliveryState: ChatDeliveryState.sending);
    setState(() {
      _sending = true;
      _messages = [
        for (final current in _messages)
          if (current.id == message.id) retry else current,
      ];
      _followBottom = true;
    });
    _pinToLatest();

    await _deliver(retry);
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      final serverId = await _client.sendMessage(
        chatId: widget.chatId,
        text: local.body,
      );
      if (!mounted) return;

      setState(() {
        _messages = [
          for (final message in _messages)
            if (message.id == local.id)
              message.copyWith(
                id: serverId,
                deliveryState: ChatDeliveryState.delivered,
                localEcho: true,
              )
            else
              message,
        ];
      });

      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _load(silent: true);
      });
    } on PyreApiException catch (e) {
      if (!mounted) return;
      _markFailed(local.id);
      _showSendFailure(e.message);
    } catch (_) {
      if (!mounted) return;
      _markFailed(local.id);
      _showSendFailure('Could not send message');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _markFailed(String localId) {
    setState(() {
      _messages = [
        for (final message in _messages)
          if (message.id == localId)
            message.copyWith(deliveryState: ChatDeliveryState.failed)
          else
            message,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SwipeBackScope(
      child: Scaffold(
        backgroundColor: _chatInk,
        body: PyreNightBackdrop(
          mood: PyreNightMood.night,
          showEmbers: false,
          child: Column(
            children: [
              _ThreadHeader(
                title: widget.title,
                topInset: top,
                onOpenPyre: _openFriendPyre,
              ),
              _ThreadConnectionStatus(status: _hubStatus),
              Expanded(child: _body()),
              _composer(bottomInset: bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: PyreColors.ember),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: PyreColors.mute)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Say hi',
          style: TextStyle(
            color: PyreColors.mute,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      );
    }

    final groups = _groupMessages(_messages);
    return ListView.builder(
      controller: _scroll,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        final lead = group.first;
        final mine = lead.senderId == widget.me.id;
        final who = _firstName(lead.displayName);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                  child: Text(
                    who,
                    style: const TextStyle(
                      color: PyreColors.nightMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final message in group)
                _MessageLine(
                  message: message,
                  mine: message.senderId == widget.me.id,
                  meId: widget.me.id,
                  onOpenSnap: () => _openSnap(message),
                  onRetry:
                      message.deliveryState == ChatDeliveryState.failed
                          ? () => _retryFailed(message)
                          : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _composer({required double bottomInset}) {
    final hasText = _input.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF20C1117),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + bottomInset),
      child: Row(
        children: [
          _ComposerIconButton(
            asset: PyreIcons.camera,
            filled: true,
            onTap: widget.onGoCamera == null ? null : _openCamera,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46, maxHeight: 112),
              padding: const EdgeInsets.only(left: 15, right: 4),
              decoration: BoxDecoration(
                color: PyreColors.nightCardStrong,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.075),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      style: const TextStyle(
                        color: PyreColors.nightText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        hintStyle: TextStyle(
                          color: PyreColors.nightMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  if (!hasText) ...[
                    const _ComposerIconButton(asset: PyreIcons.mic),
                    const _ComposerIconButton(asset: PyreIcons.gallery),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ComposerIconButton(
            asset: hasText ? PyreIcons.send : PyreIcons.smile,
            filled: hasText,
            busy: _sending,
            onTap: hasText && !_sending ? _send : null,
          ),
        ],
      ),
    );
  }
}

class _ThreadConnectionStatus extends StatelessWidget {
  const _ThreadConnectionStatus({required this.status});

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

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.title,
    required this.topInset,
    required this.onOpenPyre,
  });

  final String title;
  final double topInset;
  final VoidCallback onOpenPyre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(6, topInset + 7, 9, 9),
      decoration: BoxDecoration(
        color: const Color(0xE80B0F14),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.055),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const ColorFiltered(
              colorFilter: ColorFilter.mode(
                PyreColors.nightText,
                BlendMode.srcIn,
              ),
              child: PyreIcon(asset: PyreIcons.arrowLeft, size: 21),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9B52), Color(0xFFCB4937)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: const TextStyle(
                color: PyreColors.nightText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Direct message',
                  style: TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Visit Pyre',
            onPressed: onOpenPyre,
            icon: const Icon(
              Icons.local_fire_department_rounded,
              color: PyreColors.emberGlow,
              size: 23,
            ),
          ),
          IconButton(
            onPressed: null,
            icon: const ColorFiltered(
              colorFilter: ColorFilter.mode(
                PyreColors.nightMuted,
                BlendMode.srcIn,
              ),
              child: PyreIcon(
                asset: PyreIcons.phone,
                size: 19,
                opacity: 0.40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({
    required this.message,
    required this.mine,
    required this.meId,
    required this.onOpenSnap,
    this.onRetry,
  });

  final ChatMessage message;
  final bool mine;
  final String meId;
  final VoidCallback onOpenSnap;
  final VoidCallback? onRetry;

  String _snapStatus() {
    if (message.screenshotAt?.isNotEmpty == true) return 'Screenshot';
    if (mine) {
      return message.openedAt?.isNotEmpty == true ? 'Opened' : 'Delivered';
    }
    return message.isUnopenedFor(meId) ? 'New photo' : 'Opened';
  }

  @override
  Widget build(BuildContext context) {
    if (message.isSnap) {
      final locked = !mine && message.isUnopenedFor(meId);
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: mine
                ? PyreColors.ember.withValues(alpha: 0.20)
                : PyreColors.nightCardStrong,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onOpenSnap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      locked
                          ? Icons.photo_camera_outlined
                          : Icons.play_circle_outline_rounded,
                      size: 18,
                      color: PyreColors.emberGlow,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _snapStatus(),
                      style: const TextStyle(
                        color: PyreColors.nightText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final failed = message.deliveryState == ChatDeliveryState.failed;
    final sending = message.deliveryState == ChatDeliveryState.sending;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: mine
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF47B47),
                            Color(0xFFD94C33),
                          ],
                        )
                      : null,
                  color: mine ? null : PyreColors.nightCardStrong,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 18),
                  ),
                  border: mine
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  child: Text(
                    message.body,
                    style: const TextStyle(
                      color: PyreColors.nightText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.32,
                    ),
                  ),
                ),
              ),
              if (mine && (failed || sending))
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        failed ? 'Not sent' : 'Sending…',
                        style: TextStyle(
                          color: failed
                              ? PyreColors.busy
                              : PyreColors.nightMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (failed && onRetry != null) ...[
                        const SizedBox(width: 7),
                        GestureDetector(
                          onTap: onRetry,
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: PyreColors.emberGlow,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.asset,
    this.onTap,
    this.filled = false,
    this.busy = false,
  });

  final String asset;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Material(
      color: filled
          ? PyreColors.emberHot
          : Colors.white.withValues(alpha: 0.035),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PyreColors.ink,
                    ),
                  )
                : PyreIcon(
                    asset: asset,
                    size: filled ? 22 : 20,
                    opacity: enabled ? (filled ? 1 : 0.92) : 0.35,
                  ),
          ),
        ),
      ),
    );
  }
}
