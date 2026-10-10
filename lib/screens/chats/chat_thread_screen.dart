import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/chat_cache.dart';
import 'package:pyrechat_flutter/services/chat_draft_store.dart';
import 'package:pyrechat_flutter/services/chat_message_merge.dart';
import 'package:pyrechat_flutter/services/chat_outbox.dart';
import 'package:pyrechat_flutter/services/chat_peer_resolution.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/services/pyre_mls.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/screens/chats/snap_viewer_screen.dart';
import 'package:pyrechat_flutter/screens/pyre/friend_pyre_screen.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';
import 'package:pyrechat_flutter/widgets/swipe_back_scope.dart';

// Explain crypto readiness without leaking key material or implying plaintext fallback.
String privateSetupNotice(String? reason) {
  final lower = (reason ?? '').toLowerCase();
  if (lower.contains('invite') || lower.contains('group')) {
    return 'This browser has not joined the existing encrypted chat. Use a device already in this conversation until secure device linking is available.';
  }
  if (lower.contains('unavailable') || lower.contains('not supported')) {
    return 'Private messaging is unavailable in this browser. Use a normal tab with site storage enabled.';
  }
  if (lower.contains('peer') || lower.contains('member') ||
      lower.contains('other device')) {
    return 'Waiting for your friend to open or refresh Pyre Social in their browser. Your message stays queued.';
  }
  return 'Setting up encrypted messaging. Your message stays queued and will retry.';
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.chatId,
    required this.hub,
    required this.title,
    required this.me,
    this.peerUserId,
    this.requirePrivateText = false,
    this.openedFromNotification = false,
    this.onGoCamera,
    this.client,
    this.encryptionKeyManager,
  });

  final String chatId;
  final PyreHub hub;
  final String title;
  final PyreUser me;
  final String? peerUserId;
  final bool requirePrivateText;
  final bool openedFromNotification;
  final VoidCallback? onGoCamera;
  final PyreClient? client;
  final PyreMlsConversationManager? encryptionKeyManager;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver {
  static const _chatInk = PyreColors.night;

  late final PyreClient _client;
  late final PyreMlsConversationManager _mlsManager;
  PyrePrivateConversationCodec? _privateConversation;
  String? _privateSetupReason;
  Future<PyrePrivateConversationCodec?>? _privateConversationOpen;
  final _drafts = ChatDraftStore.instance;
  final _cache = ChatCache.instance;
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _followBottom = true;
  int _loadGeneration = 0;
  String? _error;
  Timer? _liveReloadDebounce;
  Timer? _pinTimerShort;
  Timer? _pinTimerLong;
  Timer? _typingIdle;
  Timer? _remoteTypingExpiry;
  Timer? _queuedRetryTimer;
  int _queuedRetryAttempt = 0;
  DateTime? _lastTypingSentAt;
  bool _typingSent = false;
  String? _remoteTypingName;
  bool _keepLatestAboveKeyboard = false;
  bool _networkUnavailable = false;
  bool _threadForeground = true;
  final Set<String> _receivedAcknowledged = {};
  final Set<String> _readAcknowledged = {};
  Timer? _receiptRetryTimer;
  late PyreHubStatus _hubStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _client = widget.client ?? PyreClient();
    _mlsManager = widget.encryptionKeyManager ?? PyreMlsProvisioner();
    _input.text = _drafts.draftFor(widget.chatId);
    _input.addListener(_onInputChanged);
    _inputFocus.addListener(_onInputFocusChanged);
    _scroll.addListener(_onScroll);
    _hubStatus = widget.hub.status;
    widget.hub.addListener(_onHubEvent);
    widget.hub.addStatusListener(_onHubStatus);
    unawaited(_restoreCacheAndRefresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.hub.removeListener(_onHubEvent);
    widget.hub.removeStatusListener(_onHubStatus);
    _liveReloadDebounce?.cancel();
    _pinTimerShort?.cancel();
    _pinTimerLong?.cancel();
    _typingIdle?.cancel();
    _remoteTypingExpiry?.cancel();
    _queuedRetryTimer?.cancel();
    _receiptRetryTimer?.cancel();
    _sendTypingStop();
    _input.removeListener(_onInputChanged);
    _inputFocus.removeListener(_onInputFocusChanged);
    _inputFocus.dispose();
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    unawaited(_privateConversation?.close() ?? Future<void>.value());
    super.dispose();
  }

  void _onInputChanged() {
    _drafts.setDraft(widget.chatId, _input.text);
    _updateLocalTyping();
    if (mounted) setState(() {});
  }

  void _updateLocalTyping() {
    final hasText = _input.text.trim().isNotEmpty;
    if (!hasText || !_inputFocus.hasFocus) {
      _sendTypingStop();
      return;
    }

    final now = DateTime.now();
    final shouldRefresh = !_typingSent ||
        _lastTypingSentAt == null ||
        now.difference(_lastTypingSentAt!) >= const Duration(milliseconds: 1500);
    if (shouldRefresh &&
        widget.hub.sendTyping(conversationId: widget.chatId, active: true)) {
      _typingSent = true;
      _lastTypingSentAt = now;
    }

    _typingIdle?.cancel();
    _typingIdle = Timer(const Duration(milliseconds: 2800), _sendTypingStop);
  }

  void _sendTypingStop() {
    _typingIdle?.cancel();
    _typingIdle = null;
    if (!_typingSent) return;
    widget.hub.sendTyping(conversationId: widget.chatId, active: false);
    _typingSent = false;
    _lastTypingSentAt = null;
  }

  void _onInputFocusChanged() {
    if (_inputFocus.hasFocus) {
      _keepLatestAboveKeyboard = _followBottom;
      if (_keepLatestAboveKeyboard) _pinToLatest();
      _updateLocalTyping();
      return;
    }
    _keepLatestAboveKeyboard = false;
    _sendTypingStop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _threadForeground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      _sendTypingStop();
      return;
    }
    if (!mounted) return;
    unawaited(_refreshAfterResume());
  }

  Future<void> _refreshAfterResume() async {
    await _load(silent: true);
    if (!mounted) return;
    await _flushQueuedMessages();
  }

  @override
  void didChangeMetrics() {
    if (!_keepLatestAboveKeyboard || !_inputFocus.hasFocus || !mounted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_keepLatestAboveKeyboard ||
          !_inputFocus.hasFocus ||
          !_scroll.hasClients) {
        return;
      }
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      _scroll.jumpTo(position.maxScrollExtent);
      _followBottom = true;
    });
  }

  void _onHubStatus(PyreHubStatus status) {
    if (!mounted || status == _hubStatus) return;
    final becameConnected =
        status == PyreHubStatus.connected &&
        _hubStatus != PyreHubStatus.connected;
    setState(() {
      _hubStatus = status;
      if (becameConnected) _networkUnavailable = false;
    });
    if (becameConnected) unawaited(_recoverAfterReconnect());
  }

  Future<void> _recoverAfterReconnect() async {
    await _load(silent: true);
    if (!mounted) return;
    await _flushQueuedMessages();
  }

  Future<void> _restoreCacheAndRefresh() async {
    final cachedFuture = _cache.readMessages(widget.me.id, widget.chatId);

    // Never make a fresh network read wait behind secure-storage I/O. This is
    // especially important after a notification tap, where the push already
    // tells us newer server state exists.
    final initialRefresh = _load(silent: true);
    if (widget.openedFromNotification) {
      unawaited(_reconcileNotificationOpen());
    }

    final cached = await cachedFuture;
    if (!mounted) return;

    if (cached != null) {
      final visible = _messages.isEmpty
          ? cached
          : mergeThreadMessages(
              remote: _messages,
              current: cached,
            );
      setState(() {
        _messages = visible;
        _loading = false;
        _error = null;
      });
      if (_followBottom) _pinToLatest();
    }

    await initialRefresh;
    if (!mounted) return;
    await _flushQueuedMessages();
  }

  Future<void> _reconcileNotificationOpen() async {
    // The push can beat cross-request read visibility by a short window. The
    // immediate load above is still the fast path; these quiet retries make a
    // notification-open converge without waiting for another incoming event.
    for (final delay in const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
    ]) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      await _load(silent: true);
    }
  }

  void _persistMessages() {
    unawaited(
      _cache.writeMessages(
        widget.me.id,
        widget.chatId,
        _messages,
      ),
    );
  }

  void _onHubEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final kind = event['kind'] as String?;
    final eventChatId = (event['chatId'] ??
            event['conversationId'] ??
            event['conversation_id'])
        ?.toString();

    if ((type == 'e2ee_ready' || type == 'e2ee_device_ready') &&
        eventChatId == widget.chatId) {
      _queuedRetryTimer?.cancel();
      _queuedRetryTimer = null;
      _queuedRetryAttempt = 0;
      unawaited(_flushQueuedMessages());
      return;
    }

    if (type == 'message_receipt' && eventChatId == widget.chatId) {
      _liveReloadDebounce?.cancel();
      _liveReloadDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) unawaited(_load(silent: true));
      });
      return;
    }

    if (type == 'typing') {
      if (eventChatId != widget.chatId ||
          event['from']?.toString() == widget.me.id) {
        return;
      }
      final active = event['active'] != false;
      _remoteTypingExpiry?.cancel();
      if (!active) {
        if (mounted && _remoteTypingName != null) {
          setState(() => _remoteTypingName = null);
        }
        return;
      }
      final name = event['fromName']?.toString().trim();
      if (mounted) {
        setState(() {
          _remoteTypingName =
              name == null || name.isEmpty ? widget.title : name;
          _followBottom = true;
        });
        _pinToLatest();
      }
      _remoteTypingExpiry = Timer(const Duration(milliseconds: 3800), () {
        if (mounted && _remoteTypingName != null) {
          setState(() => _remoteTypingName = null);
        }
      });
      return;
    }

    if (type != 'chat' &&
        type != 'snap' &&
        type != 'notification' &&
        kind != 'snap') {
      return;
    }

    if (eventChatId != null &&
        eventChatId.isNotEmpty &&
        eventChatId != widget.chatId) {
      return;
    }

    if (type == 'chat' && _remoteTypingName != null && mounted) {
      _remoteTypingExpiry?.cancel();
      setState(() => _remoteTypingName = null);
    }

    _liveReloadDebounce?.cancel();
    _liveReloadDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load(silent: true);
    });
  }

  // Missing peer/avatar metadata must never downgrade a direct chat to plaintext.
  bool get _privateTextEligible =>
      widget.requirePrivateText ||
      widget.peerUserId?.trim().isNotEmpty == true;

  String? get _resolvedPeerUserId => resolveDirectChatPeerId(
        meId: widget.me.id,
        requiresPrivateText: _privateTextEligible,
        peerUserId: widget.peerUserId,
        messageSenderIds: _messages.map((message) => message.senderId),
      );

  Future<PyrePrivateConversationCodec?> _ensurePrivateConversation({
    bool refresh = false,
  }) async {
    if (!_privateTextEligible) return null;
    if (!refresh && _privateConversation != null) return _privateConversation;
    if (!refresh && _privateConversationOpen != null) {
      return _privateConversationOpen!;
    }

    if (refresh && _privateConversation != null) {
      await _privateConversation!.close();
      _privateConversation = null;
    }

    final opening = _mlsManager
        .openConversation(
          client: _client,
          userId: widget.me.id,
          chatId: widget.chatId,
        )
        .then((result) {
          final reason = result.conversation == null ? result.waitingReason : null;
          if (mounted && _privateSetupReason != reason) {
            setState(() => _privateSetupReason = reason);
          }
          return result.conversation;
        });
    _privateConversationOpen = opening;
    try {
      final conversation = await opening;
      if (!mounted) {
        await conversation?.close();
        return null;
      }
      _privateConversation = conversation;
      return conversation;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PyreThread] private-message setup: ${error.runtimeType}');
      }
      if (mounted && _privateSetupReason != 'Encryption setup encountered an error') {
        setState(() => _privateSetupReason = 'Encryption setup encountered an error');
      }
      return null;
    } finally {
      if (identical(_privateConversationOpen, opening)) {
        _privateConversationOpen = null;
      }
    }
  }

  Future<List<ChatMessage>> _resolvePrivateMessages(
    List<ChatMessage> messages,
  ) async {
    if (!messages.any((message) => message.kind == 'mls')) return messages;

    final conversation = await _ensurePrivateConversation();
    final resolved = <ChatMessage>[];
    for (final message in messages) {
      if (message.kind != 'mls') {
        resolved.add(message);
        continue;
      }

      String? text;
      if (conversation != null) {
        try {
          text = await conversation.decryptMessage(
            messageId: message.id,
            ciphertext: message.body,
            sentByMe: message.senderId == widget.me.id,
          );
        } catch (error) {
          if (kDebugMode) {
            debugPrint(
              '[PyreThread] private-message read: ${error.runtimeType}',
            );
          }
        }
      }

      resolved.add(
        message.copyWith(
          kind: 'text',
          body: text ?? 'Private message unavailable on this device',
        ),
      );
    }
    return resolved;
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
      final remoteMessages = await _client.messages(widget.chatId);
      final messages = await _resolvePrivateMessages(remoteMessages);
      if (!mounted || generation != _loadGeneration) return;
      final merged = mergeThreadMessages(
        remote: messages,
        current: _messages,
      );
      setState(() {
        _messages = merged;
        _loading = false;
        _error = null;
        _networkUnavailable = false;
      });
      _persistMessages();
      if (_followBottom) _pinToLatest();
      unawaited(_acknowledgeVisibleMessages(remoteMessages, messages));
    } on PyreApiException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[PyreThread] message load failed: '
          'status=${e.statusCode ?? 'none'}',
        );
      }
      if (!mounted || generation != _loadGeneration) return;
      final offline = e.statusCode == null;
      setState(() {
        _networkUnavailable = offline || _networkUnavailable;
        _loading = false;
        if (!silent && _messages.isEmpty) {
          _error = e.safeChatLoadMessage;
        }
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[PyreThread] message load failed: ${error.runtimeType}: $error',
        );
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _networkUnavailable = true;
        _loading = false;
        if (!silent && _messages.isEmpty) {
          _error = 'Could not load messages';
        }
      });
    }
  }

  Future<void> _acknowledgeVisibleMessages(
    List<ChatMessage> remote,
    List<ChatMessage> resolved,
  ) async {
    // Never acknowledge local echoes or claim "read" for ciphertext that this
    // installation could not decrypt. Delivery and read are distinct events.
    final received = remote.where((m) =>
        m.senderId != widget.me.id &&
        (m.kind == 'text' || m.kind == 'mls' || m.kind == 'sticker')).map((m) => m.id).toList(growable: false);
    await _acknowledgeBatch(received, read: false);
    if (!mounted || !_threadForeground) return;
    final readable = resolved.where((m) =>
        m.senderId != widget.me.id &&
        (m.kind == 'text' || m.kind == 'sticker') &&
        m.body != 'Private message unavailable on this device').map((m) => m.id).toList(growable: false);
    await _acknowledgeBatch(readable, read: true);
  }

  Future<void> _acknowledgeBatch(List<String> ids, {required bool read}) async {
    if (!mounted || ids.isEmpty) return;
    final recorded = read ? _readAcknowledged : _receivedAcknowledged;
    final remaining = ids.where((id) => !recorded.contains(id)).toList(growable: false);
    for (var i = 0; i < remaining.length; i += 75) {
      final end = (i + 75).clamp(0, remaining.length);
      final batch = remaining.sublist(i, end);
      recorded.addAll(batch);
      try {
        await _client.acknowledgeMessages(
          chatId: widget.chatId,
          messageIds: batch,
          read: read,
        );
      } catch (_) {
        recorded.removeAll(batch);
        if (mounted && !(_receiptRetryTimer?.isActive ?? false)) {
          _receiptRetryTimer = Timer(const Duration(seconds: 15), () {
            _receiptRetryTimer = null;
            if (mounted) unawaited(_load(silent: true));
          });
        }
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
    _pinTimerShort?.cancel();
    _pinTimerLong?.cancel();
    _pinTimerShort = Timer(const Duration(milliseconds: 80), () {
      if (mounted) jump();
    });
    _pinTimerLong = Timer(const Duration(milliseconds: 240), () {
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

  static const Map<String, String> _reportReasons = {
    'spam': 'Spam or scams',
    'harassment': 'Harassment or bullying',
    'hate': 'Hate or abusive conduct',
    'sexual': 'Sexual content',
    'violence': 'Violence or threats',
    'self_harm': 'Self-harm concern',
    'child_safety': 'Child safety',
    'impersonation': 'Impersonation',
    'illegal': 'Illegal activity',
    'other': 'Something else',
  };

  Future<String?> _chooseReportReason(String title) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101419),
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Text(
                title,
                style: const TextStyle(
                  color: PyreColors.nightText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final entry in _reportReasons.entries)
              ListTile(
                title: Text(
                  entry.value,
                  style: const TextStyle(
                    color: PyreColors.nightText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportPeer() async {
    final peerUserId = _resolvedPeerUserId;
    if (peerUserId == null || peerUserId.isEmpty) return;
    final reason = await _chooseReportReason('Report ${widget.title}');
    if (reason == null || !mounted) return;

    try {
      await _client.reportUser(
        userId: peerUserId,
        reason: reason,
        detail: 'Reported from direct conversation ${widget.chatId}.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted.')),
      );
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    if (message.senderId == widget.me.id) return;
    final reason = await _chooseReportReason(
      message.isSnap ? 'Report this Pyre' : 'Report this message',
    );
    if (reason == null || !mounted) return;

    try {
      if (message.isSnap) {
        await _client.reportSnap(
          snapId: message.id,
          reason: reason,
          detail: 'Reported from conversation ${widget.chatId}.',
        );
      } else {
        await _client.reportMessage(
          messageId: message.id,
          reason: reason,
          detail: 'Reported from conversation ${widget.chatId}.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted.')),
      );
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _blockPeer() async {
    final peerUserId = _resolvedPeerUserId;
    if (peerUserId == null || peerUserId.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: PyreColors.paper,
            title: Text(
              'Block ${widget.title}?',
              style: const TextStyle(
                color: PyreColors.onPaper,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              'They will no longer be able to contact you, and you will be removed from each other’s friends lists.',
              style: TextStyle(color: PyreColors.onPaperMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Block'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await _client.blockUser(peerUserId);
      await _cache.deleteThread(widget.me.id, widget.chatId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _showSafetyMenu() async {
    final peerUserId = _resolvedPeerUserId;
    if (peerUserId == null || peerUserId.isEmpty) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101419),
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: PyreColors.emberGlow,
                ),
                title: const Text(
                  'Report user',
                  style: TextStyle(
                    color: PyreColors.nightText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'Send this account to PyreChat safety review.',
                  style: TextStyle(color: PyreColors.nightMuted),
                ),
                onTap: () => Navigator.of(sheetContext).pop('report'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Block user',
                  style: TextStyle(
                    color: PyreColors.nightText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'Stop contact and remove the friendship.',
                  style: TextStyle(color: PyreColors.nightMuted),
                ),
                onTap: () => Navigator.of(sheetContext).pop('block'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'report') await _reportPeer();
    if (action == 'block') await _blockPeer();
  }

  void _showSendFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Not sent — $message')),
    );
  }

  void _showQueuedNotice({bool waitingForKeys = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(waitingForKeys
            ? privateSetupNotice(_privateSetupReason)
            : 'Queued — will retry automatically when the connection recovers'),
      ),
    );
  }

  void _scheduleQueuedRetry() {
    if (!mounted || (_queuedRetryTimer?.isActive ?? false)) return;
    const delays = [2, 4, 8, 15, 30];
    final index = _queuedRetryAttempt.clamp(0, delays.length - 1);
    _queuedRetryAttempt += 1;
    _queuedRetryTimer = Timer(Duration(seconds: delays[index]), () {
      _queuedRetryTimer = null;
      if (mounted) unawaited(_flushQueuedMessages());
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _sendTypingStop();

    // The HTTP message endpoint works independently of the realtime hub.
    // Always attempt delivery; only queue after an actual transport failure.
    final temp = ChatMessage(
      id: newOutgoingClientMessageId(),
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
    _persistMessages();
    _input.clear();
    _pinToLatest();

    await _deliver(temp);
  }

  Future<void> _trySendStandard(ChatMessage local) async {
    if (!mounted || _sending || _privateConversation != null) return;
    try {
      if (await _client.isChatEndToEndEncrypted(widget.chatId)) {
        if (mounted) {
          _showSendFailure(
            'This conversation already uses end-to-end encryption. Standard fallback is unavailable.',
          );
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        _showSendFailure('Could not verify conversation encryption; try again later.');
      }
      return;
    }
    if (!mounted) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send without end-to-end encryption?'),
        content: const Text(
          'This one message will be stored as standard chat text on Pyre Social servers. '
          'It will not have end-to-end encryption. Other messages remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep private'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send standard'),
          ),
        ],
      ),
    );
    if (!mounted || consent != true || _sending || _privateConversation != null) return;

    final queued = _messages.any((message) =>
        message.id == local.id && message.deliveryState == ChatDeliveryState.queued);
    if (!queued) return;
    _queuedRetryTimer?.cancel();
    _queuedRetryTimer = null;
    setState(() {
      _sending = true;
      _messages = [
        for (final m in _messages)
          m.id == local.id
              ? m.copyWith(deliveryState: ChatDeliveryState.sending, encrypted: false)
              : m,
      ];
    });
    _persistMessages();
    try {
      final serverId = await _client.sendMessage(
        chatId: widget.chatId,
        text: local.body,
        clientId: local.id,
      );
      if (!mounted) return;
      setState(() {
        _messages = reconcileDeliveredLocalEcho(
          current: _messages,
          localId: local.id,
          serverId: serverId,
        );
      });
      _persistMessages();
      _queuedRetryAttempt = 0;
      unawaited(_load(silent: true));
    } on PyreApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        _markQueued(local.id);
        _scheduleQueuedRetry();
        _showSendFailure(
          'This conversation now requires encryption. Your message remains queued securely.',
        );
      } else {
        _markFailed(local.id);
        _showSendFailure(error.safeChatSendMessage);
      }
    } catch (_) {
      if (!mounted) return;
      _markQueued(local.id);
      _scheduleQueuedRetry();
      _showSendFailure('Could not send standard message. It remains queued.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
    _persistMessages();
    _pinToLatest();

    await _deliver(retry);
  }

  Future<void> _flushQueuedMessages() async {
    if (!mounted || _sending) return;

    final queued = queuedTextMessagesForRetry(
      _messages,
      senderId: widget.me.id,
    );
    for (final snapshot in queued) {
      if (!mounted || _sending) {
        return;
      }

      ChatMessage? current;
      for (final message in _messages) {
        if (message.id == snapshot.id) {
          current = message;
          break;
        }
      }
      if (current == null ||
          current.deliveryState != ChatDeliveryState.queued) {
        continue;
      }

      final sending =
          current.copyWith(deliveryState: ChatDeliveryState.sending);
      setState(() {
        _sending = true;
        _messages = [
          for (final message in _messages)
            if (message.id == current!.id) sending else message,
        ];
      });
      _persistMessages();

      await _deliver(sending, notifyFailure: false);
      if (!mounted) return;

      final stillQueued = _messages.any(
        (message) =>
            message.id == snapshot.id &&
            message.deliveryState == ChatDeliveryState.queued,
      );
      if (stillQueued) return;
    }
  }

  Future<String> _sendThreadText(ChatMessage local) async {
    if (!_privateTextEligible) {
      return _client.sendMessage(
        chatId: widget.chatId,
        text: local.body,
        clientId: local.id,
      );
    }

    final privateConversation = await _ensurePrivateConversation();
    if (privateConversation == null) {
      throw PyreApiException(
        'Private messaging is still setting up. Try again in a moment.',
        409,
      );
    }

    final ciphertext = await privateConversation.encryptForSend(
      messageId: local.id,
      plaintext: local.body,
    );
    return _client.sendMlsMessage(
      chatId: widget.chatId,
      ciphertext: ciphertext,
      clientId: local.id,
    );
  }
  Future<void> _deliver(
    ChatMessage local, {
    bool notifyFailure = true,
  }) async {
    try {
      final serverId = await _sendThreadText(local);
      if (!mounted) return;

      setState(() {
        _messages = reconcileDeliveredLocalEcho(
          current: [
            for (final message in _messages)
              if (message.id == local.id && _privateTextEligible)
                message.copyWith(encrypted: true)
              else
                message,
          ],
          localId: local.id,
          serverId: serverId,
        );
      });
      _persistMessages();
      _queuedRetryAttempt = 0;

      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _load(silent: true);
      });
    } on PyreApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == null || e.statusCode == 408 ||
          e.statusCode == 429 || (e.statusCode ?? 0) >= 500) {
        // Timeouts, rate limits, and server outages do not prove non-delivery.
        // Retry this exact client id / original encrypted payload later.
        _markQueued(local.id, networkUnavailable: e.statusCode == null);
        _scheduleQueuedRetry();
        if (notifyFailure) _showQueuedNotice();
      } else if (e.statusCode == 409 &&
          (e.message ==
              'Private messaging is still setting up. Try again in a moment.' ||
           e.message == 'Encrypted conversation is not ready')) {
        // Never fall back to plaintext. Hold the optimistic message until the
        // recipient's encrypted session is available, then retry automatically.
        _markQueued(local.id);
        _scheduleQueuedRetry();
        if (notifyFailure) _showQueuedNotice(waitingForKeys: true);
      } else {
        _markFailed(local.id);
        if (notifyFailure) _showSendFailure(e.safeChatSendMessage);
      }
    } catch (_) {
      if (!mounted) return;
      // An unexpected MLS/runtime error is not evidence of network loss.
      // Require explicit retry rather than silently auto-resending it.
      _markFailed(local.id);
      if (notifyFailure) {
        _showSendFailure(
          _privateTextEligible
              ? 'Private message could not be protected or sent. Retry manually.'
              : 'Message could not be sent. Retry manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _markQueued(
    String localId, {
    bool networkUnavailable = false,
  }) {
    setState(() {
      if (networkUnavailable) _networkUnavailable = true;
      _messages = [
        for (final message in _messages)
          if (message.id == localId &&
              message.deliveryState == ChatDeliveryState.sending)
            message.copyWith(deliveryState: ChatDeliveryState.queued)
          else
            message,
      ];
    });
    _persistMessages();
  }

  void _markFailed(String localId) {
    setState(() {
      _messages = [
        for (final message in _messages)
          if (message.id == localId &&
              message.deliveryState == ChatDeliveryState.sending)
            message.copyWith(deliveryState: ChatDeliveryState.failed)
          else
            message,
      ];
    });
    _persistMessages();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SwipeBackScope(
      child: Scaffold(
        backgroundColor: _chatInk,
        body: PyreNightBackdrop(
          mood: PyreSurfaceMood.chatThread,
          showEmbers: false,
          child: Column(
            children: [
              _ThreadHeader(
                title: widget.title,
                topInset: top,
                onOpenPyre: _openFriendPyre,
                encryptionReady: _privateConversation != null,
                onSafety: _resolvedPeerUserId != null
                    ? _showSafetyMenu
                    : null,
              ),
              _ThreadConnectionStatus(
                status: _hubStatus,
                networkUnavailable: _networkUnavailable,
              ),
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
    if (_networkUnavailable && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You are offline. This thread is not saved on this device yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PyreColors.mute),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_error != null && _messages.isEmpty) {
      final message = _error!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PyreColors.mute),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty && _remoteTypingName == null) {
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
    final hasTyping = _remoteTypingName != null;
    return ListView.builder(
      controller: _scroll,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      itemCount: groups.length + (hasTyping ? 1 : 0),
      itemBuilder: (context, i) {
        if (hasTyping && i == groups.length) {
          return _TypingBubble(name: _firstName(_remoteTypingName!));
        }
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
                  onSendStandard: _privateTextEligible &&
                          message.deliveryState == ChatDeliveryState.queued &&
                          _privateConversation == null &&
                          _privateSetupReason != null &&
                          !_privateSetupReason!.toLowerCase().contains('invite')
                      ? () => _trySendStandard(message)
                      : null,
                  onReport: message.senderId == widget.me.id
                      ? null
                      : () => _reportMessage(message),
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
        color: const Color(0xFA090C10),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(10, 7, 10, 7 + bottomInset),
      child: Row(
        children: [
          Tooltip(
            message: 'Open camera',
            excludeFromSemantics: true,
            child: _ComposerIconButton(
              asset: PyreIcons.navCameraActive,
              semanticLabel: 'Open camera',
              onTap: widget.onGoCamera == null ? null : _openCamera,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 112),
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.065),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
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
                ],
              ),
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: _sending ? 'Sending message' : 'Send message',
              excludeFromSemantics: true,
              child: _ComposerIconButton(
                asset: PyreIcons.actionSendPlane,
                semanticLabel:
                    _sending ? 'Sending message' : 'Send message',
                artworkFrame: true,
                busy: _sending,
                onTap: _sending ? null : _send,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.name});

  final String name;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Text(
              widget.name,
              style: const TextStyle(
                color: PyreColors.nightMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 2),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(15),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final shifted =
                        (_controller.value - index * 0.18) % 1.0;
                    final pulse = shifted < 0.5
                        ? shifted * 2
                        : (1 - shifted) * 2;
                    return Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
                      child: Transform.translate(
                        offset: Offset(0, -2.5 * pulse),
                        child: Opacity(
                          opacity: 0.35 + (0.65 * pulse),
                          child: const CircleAvatar(
                            radius: 3.3,
                            backgroundColor: PyreColors.emberGlow,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadConnectionStatus extends StatelessWidget {
  const _ThreadConnectionStatus({
    required this.status,
    required this.networkUnavailable,
  });

  final PyreHubStatus status;
  final bool networkUnavailable;

  @override
  Widget build(BuildContext context) {
    if (!networkUnavailable && status == PyreHubStatus.connected) {
      return const SizedBox.shrink();
    }

    final label = networkUnavailable || status == PyreHubStatus.disconnected
        ? 'You are offline'
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

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.title,
    required this.topInset,
    required this.onOpenPyre,
    required this.encryptionReady,
    this.onSafety,
  });

  final String title;
  final double topInset;
  final VoidCallback onOpenPyre;
  final bool encryptionReady;
  final VoidCallback? onSafety;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(6, topInset + 6, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xF70A0D11),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.055),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to chats',
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
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.065),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      encryptionReady ? Icons.lock_outline_rounded : Icons.lock_clock_outlined,
                      color: PyreColors.nightMuted,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        encryptionReady ? 'End-to-end encrypted' : 'Preparing private messaging',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PyreColors.nightMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
            tooltip: onSafety == null ? null : 'Safety & conversation',
            onPressed: onSafety,
            icon: Icon(
              Icons.more_vert_rounded,
              color: onSafety == null
                  ? PyreColors.nightMuted.withValues(alpha: 0.4)
                  : PyreColors.nightText,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// RCS-style acknowledgments use recipient-confirmed evidence, never the
/// presence/absence of encryption as a stand-in for delivery status.
enum MessageReceiptKind { sent, delivered, read }

MessageReceiptKind receiptKind(ChatMessage message) {
  if (message.readAt?.isNotEmpty == true) return MessageReceiptKind.read;
  if (message.deliveredAt?.isNotEmpty == true) return MessageReceiptKind.delivered;
  return MessageReceiptKind.sent;
}

class _MessageReceiptIndicator extends StatelessWidget {
  const _MessageReceiptIndicator({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final receipt = receiptKind(message);
    final read = receipt == MessageReceiptKind.read;
    final label = receipt == MessageReceiptKind.sent
        ? 'Sent'
        : receipt == MessageReceiptKind.delivered ? 'Delivered' : 'Read';
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Icon(
          receipt == MessageReceiptKind.sent
              ? Icons.done_rounded
              : Icons.done_all_rounded,
          size: 15,
          color: read ? PyreColors.emberGlow : PyreColors.nightMuted,
        ),
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
    this.onSendStandard,
    this.onReport,
  });

  final ChatMessage message;
  final bool mine;
  final String meId;
  final VoidCallback onOpenSnap;
  final VoidCallback? onRetry;
  final VoidCallback? onSendStandard;
  final VoidCallback? onReport;

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
                ? PyreColors.ember.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onOpenSnap,
              onLongPress: onReport,
              borderRadius: BorderRadius.circular(15),
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
    final queued = message.deliveryState == ChatDeliveryState.queued;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.74,
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: onReport,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                  color: mine
                      ? PyreColors.emberHot.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 16),
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
              ),
              if (mine)
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (failed || sending || queued)
                        Text(
                          failed ? 'Not sent' : queued ? 'Queued' : 'Sending…',
                          style: TextStyle(
                            color: failed ? PyreColors.busy : PyreColors.nightMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        _MessageReceiptIndicator(message: message),
                      if (!failed && !sending && !queued) ...[
                        const SizedBox(width: 5),
                        Tooltip(
                          message: message.encrypted
                              ? 'End-to-end encrypted'
                              : 'Standard message — not end-to-end encrypted',
                          child: Icon(
                            message.encrypted ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                            size: 11,
                            color: PyreColors.nightMuted,
                          ),
                        ),
                      ],
                      if (failed && onRetry != null) ...[
                        const SizedBox(width: 3),
                        Semantics(
                          button: true,
                          label: 'Retry failed message',
                          child: Tooltip(
                            message: 'Retry failed message',
                            excludeFromSemantics: true,
                            child: InkWell(
                              onTap: onRetry,
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: Text(
                                    'Retry',
                                    style: const TextStyle(
                                      color: PyreColors.emberGlow,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (mine && queued && onSendStandard != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: TextButton.icon(
                    onPressed: onSendStandard,
                    style: TextButton.styleFrom(
                      foregroundColor: PyreColors.emberGlow,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 12),
                    label: const Text('Send standard', style: TextStyle(fontSize: 11)),
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
    required this.semanticLabel,
    this.onTap,
    this.busy = false,
    this.artworkFrame = false,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool busy;
  final bool artworkFrame;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
      color: artworkFrame
          ? Colors.transparent
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
                      color: PyreColors.emberGlow,
                    ),
                  )
                : PyreIcon(
                    asset: asset,
                    size: artworkFrame ? 42 : 25,
                    opacity: enabled ? 1 : 0.35,
                  ),
          ),
        ),
      ),
      ),
    );
  }
}