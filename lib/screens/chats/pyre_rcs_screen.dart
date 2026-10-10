import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/pyre_rcs.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

/// A real UI for the independent PyreSocial RCS Worker.
///
/// RCS is the sole account identity for fresh installs. The previous
/// password/legacy chat infrastructure is not used for onboarding or messaging.
class PyreRcsInboxScreen extends StatefulWidget {
  const PyreRcsInboxScreen({super.key, this.user, this.client});
  /// Backward-compatible optional scope for previously signed-in builds.
  /// New installs always use the independent RCS account identity.
  final PyreUser? user;
  final PyreRcsClient? client;

  @override
  State<PyreRcsInboxScreen> createState() => _PyreRcsInboxScreenState();
}

class _PyreRcsInboxScreenState extends State<PyreRcsInboxScreen>
    with WidgetsBindingObserver {
  late final PyreRcsClient _rcs;
  late final bool _ownsClient;
  final _peerInput = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<PyreRcsMessage> _history = [];
  final Set<String> _inboxDelivered = {};
  Timer? _refreshDebounce;
  Timer? _pushRegistrationRetry;
  int _pushRegistrationAttempts = 0;
  bool _busy = true;
  bool _loadingMessages = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _rcs = widget.client ?? PyreRcsClient(
      accountScope: widget.user?.id ?? 'pyresocial-rcs-primary-v1',
    );
    _rcs.addListener(_onRcsEvent);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    _pushRegistrationRetry?.cancel();
    _rcs.removeListener(_onRcsEvent);
    if (_ownsClient) _rcs.dispose();
    _peerInput.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) {
      unawaited(_refresh());
      unawaited(_rcs.connect());
      _registerBackgroundDelivery();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pushRegistrationRetry?.cancel();
    }
  }

  void _registerBackgroundDelivery() {
    if (!mounted || !_ready || !_ownsClient || kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _pushRegistrationRetry?.cancel();
    unawaited(_rcs.registerAndroidBackgroundDelivery().then((registered) {
      if (!mounted || !_ready) return;
      if (registered) {
        _pushRegistrationAttempts = 0;
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == AppLifecycleState.paused ||
          lifecycle == AppLifecycleState.hidden ||
          lifecycle == AppLifecycleState.detached) {
        return;
      }
      // Firebase may return no token while Play Services initializes. Do
      // not give up permanently after one launch-time callback.
      const delays = [8, 16, 30, 60];
      final index = _pushRegistrationAttempts.clamp(0, delays.length - 1);
      _pushRegistrationAttempts++;
      _pushRegistrationRetry = Timer(
        Duration(seconds: delays[index]),
        _registerBackgroundDelivery,
      );
    }).catchError((Object _) {
      // Optional background delivery must not disrupt the live RCS inbox.
    }));
  }

  void _onRcsEvent() {
    if (!mounted || !_ready) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _rcs.ready();
      if (!mounted) return;
      setState(() => _ready = true);
      await _refresh();
      unawaited(_rcs.connect());
      _registerBackgroundDelivery();
    } on PyreRcsException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'The independent RCS service cannot be initialized.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (!_ready || _loadingMessages) return;
    _loadingMessages = true;
    try {
      final items = await _rcs.history();
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(items);
        _error = null;
      });
      // An open inbox is a real receiving app even without a thread open.
      // Never call IMDN based solely on server storage or a notification.
      final newest = items.where((m) => m.incoming).toList();
      final deliverable = newest.length > 50
          ? newest.sublist(newest.length - 50)
          : newest;
      for (final msg in deliverable) {
        final dedupe = '${msg.peer}:${msg.id}';
        if (!_inboxDelivered.add(dedupe)) continue;
        unawaited(_rcs.acknowledge(msg.peer, msg.id)
            .catchError((Object _) { _inboxDelivered.remove(dedupe); }));
      }
    } on PyreRcsException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load RCS messages.');
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _openPeer(String peer) async {
    try {
      final handle = PyreRcsProtocol.peerHandle(peer);
      if (!_ready) throw const PyreRcsException('RCS identity is not ready.');
      if (handle == _rcs.handle) {
        throw const PyreRcsException('Cannot start a chat with yourself.');
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PyreRcsThreadScreen(client: _rcs, peer: handle),
        ),
      );
      if (mounted) unawaited(_refresh());
    } on PyreRcsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Identity detail is presentation only; the real RCS address stays intact.
  Future<void> _showMyAddress() async {
    final address = _rcs.address;
    if (address == null) return;
    final pushHealth = _ownsClient && !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android
        ? _rcs.backgroundDeliveryHealth()
        : null;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: PyreColors.nightRaised,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your address',
                style: TextStyle(
                  color: PyreColors.nightText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share this address so someone can message you.',
                style: TextStyle(color: PyreColors.nightMuted),
              ),
              const SizedBox(height: 20),
              SelectableText(
                address,
                style: const TextStyle(
                  color: PyreColors.nightText,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('rcs_copy_address'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy address'),
              ),
              if (pushHealth != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Android background delivery',
                  style: TextStyle(
                    color: PyreColors.nightText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AnimatedBuilder(
                  animation: _rcs,
                  builder: (_, __) => Text(
                    _rcs.backgroundDeliveryNote,
                    style: const TextStyle(
                      color: PyreColors.nightMuted, fontSize: 12,
                    ),
                  ),
                ),
                FutureBuilder<Map<String, dynamic>?>(
                  future: pushHealth,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    if (data == null) {
                      return const Text('Checking push server…',
                        style: TextStyle(color: PyreColors.nightMuted, fontSize: 12));
                    }
                    final result = data['lastProviderResult']?.toString();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['registered'] == true ? 'Server: device registered'
                              : 'Server: device not registered',
                          style: const TextStyle(
                            color: PyreColors.nightMuted, fontSize: 12),
                        ),
                        if (result != null)
                          Text('Last Firebase wake: $result',
                            style: const TextStyle(
                              color: PyreColors.nightMuted, fontSize: 12)),
                        if (data['lastDeviceReceiptAt'] != null)
                          const Text('Android background receipt confirmed previously',
                            style: TextStyle(
                              color: PyreColors.nightMuted, fontSize: 12)),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'RCS text is not yet end-to-end encrypted. Do not send sensitive content.',
                style: TextStyle(color: PyreColors.nightMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Previews are built from locally fetched CPIM, never the FCM wake.
  Future<void> _showNotificationSettings() async {
    var showPreviews = true;
    try {
      showPreviews = await _rcs.notificationPreviewsEnabled();
    } catch (_) {
      // Older Android builds may lack the native preference channel.
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Message notifications'),
          content: SwitchListTile.adaptive(
            key: const Key('rcs_notification_previews_switch'),
            title: const Text('Show message previews'),
            subtitle: const Text(
              'Include message text in Android notifications. '
              'When off, notifications simply say New message.',
            ),
            value: showPreviews,
            onChanged: (enabled) async {
              try {
                final saved = await _rcs.setNotificationPreviewsEnabled(enabled);
                if (!dialogContext.mounted) return;
                if (saved) {
                  updateDialog(() => showPreviews = enabled);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Could not save notification preference')),
                  );
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Notification preference unavailable')),
                  );
                }
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newMessage() async {
    if (!_ready) return;
    _peerInput.clear();
    final peer = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PyreColors.nightRaised,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Form(
              key: _formKey,
              // The compact composer eagerly builds Continue even when
              // the keyboard shrinks the visible sheet height.
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const Text(
                    'New message',
                    style: TextStyle(
                      color: PyreColors.nightText,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter an RCS address or handle.',
                    style: TextStyle(color: PyreColors.nightMuted),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('rcs_peer_handle'),
                    controller: _peerInput,
                    autofocus: true,
                    style: const TextStyle(color: PyreColors.nightText),
                    textInputAction: TextInputAction.go,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      hintText: 'RCS address or handle',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) {
                      try {
                        PyreRcsProtocol.peerHandle(value ?? '');
                        return null;
                      } catch (_) {
                        return 'Enter a valid Pyre RCS address';
                      }
                    },
                    onFieldSubmitted: (_) {
                      if (_formKey.currentState?.validate() ?? false) {
                        Navigator.of(sheetContext).pop(_peerInput.text.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('rcs_open_peer'),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        Navigator.of(sheetContext).pop(_peerInput.text.trim());
                      }
                    },
                    child: const Text('Continue'),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted && peer != null) await _openPeer(peer);
  }

  @override
  Widget build(BuildContext context) {
    final recent = <String, PyreRcsMessage>{};
    for (final message in _history) {
      final last = recent[message.peer];
      if (last == null || message.sequence > last.sequence) {
        recent[message.peer] = message;
      }
    }
    final conversations = recent.entries.toList()
      ..sort((a, b) => b.value.sequence.compareTo(a.value.sequence));

    // The dark Material 3 inbox theme is local to this screen.
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PyreColors.emberGlow,
        brightness: Brightness.dark,
        surface: PyreColors.night,
      ),
      scaffoldBackgroundColor: PyreColors.night,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PyreColors.nightCardStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PyreColors.nightLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PyreColors.nightLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PyreColors.emberGlow, width: 1.5),
        ),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: PyreColors.night,
          foregroundColor: PyreColors.nightText,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Messages',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              IconButton(
                key: const Key('rcs_notification_settings'),
                tooltip: 'Notification settings',
                onPressed: _showNotificationSettings,
                icon: const Icon(Icons.notifications_outlined),
              ),
            IconButton(
              key: const Key('rcs_account'),
              tooltip: 'Your RCS address',
              onPressed: _rcs.address == null ? null : _showMyAddress,
              icon: const Icon(Icons.account_circle_outlined, size: 28),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: _ready
            ? FloatingActionButton.extended(
                key: const Key('rcs_new_message'),
                onPressed: _newMessage,
                backgroundColor: PyreColors.emberGlow,
                foregroundColor: PyreColors.night,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('New message'),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 108),
                  children: [
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null)
                      Card(
                        color: PyreColors.nightRaised,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: PyreColors.nightText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _busy ? null : _bootstrap,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_ready && conversations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 112),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: PyreColors.nightMuted,
                            ),
                            SizedBox(height: 18),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                color: PyreColors.nightText,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap New message to start a conversation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: PyreColors.nightMuted),
                            ),
                          ],
                        ),
                      ),
                    for (final conversation in conversations) ...[
                      ListTile(
                        key: Key('rcs_peer_${conversation.key}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(
                          radius: 23,
                          backgroundColor: PyreColors.nightLine,
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: PyreColors.emberGlow,
                          ),
                        ),
                        title: Text(
                          conversation.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PyreColors.nightText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          conversation.value.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: PyreColors.nightMuted),
                        ),
                        onTap: () => _openPeer(conversation.key),
                      ),
                      const Divider(
                        height: 1,
                        indent: 82,
                        endIndent: 12,
                        color: PyreColors.nightLine,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// One peer conversation on the independent RCS mailbox.
class PyreRcsThreadScreen extends StatefulWidget {
  const PyreRcsThreadScreen({
    super.key,
    required this.client,
    required this.peer,
  });
  final PyreRcsClient client;
  final String peer;

  @override
  State<PyreRcsThreadScreen> createState() => _PyreRcsThreadScreenState();
}

class _PyreRcsThreadScreenState extends State<PyreRcsThreadScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _delivered = <String>{};
  final _read = <String>{};
  final _messages = <PyreRcsMessage>[];
  // Historical CPIM rows preserve their original state; the RCS status API
  // reports the authoritative delivered/displayed progression.
  final _outgoingStates = <String, String>{};
  Timer? _refreshDebounce;
  Timer? _idleTimer;
  DateTime? _lastTyping;
  bool _sending = false;
  bool _refreshing = false;
  bool _refreshPending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.client.addListener(_onMessage);
    _composer.addListener(_onCompose);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    _idleTimer?.cancel();
    if (_lastTyping != null) {
      unawaited(widget.client.typing(widget.peer, active: false)
          .catchError((Object _) {}));
    }
    widget.client.removeListener(_onMessage);
    _composer.removeListener(_onCompose);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  void _onMessage() {
    if (!mounted) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_refresh());
    });
  }

  void _onCompose() {
    // Empty or whitespace-only drafts must stop peer typing presence at once,
    // including after a successful send, instead of waiting for the idle timer.
    if (_composer.text.trim().isEmpty) {
      _idleTimer?.cancel();
      _idleTimer = null;
      if (_lastTyping != null) {
        _lastTyping = null;
        unawaited(widget.client.typing(widget.peer, active: false)
            .catchError((Object _) {}));
      }
      return;
    }
    final now = DateTime.now();
    if (_lastTyping == null ||
        now.difference(_lastTyping!) > const Duration(seconds: 2)) {
      _lastTyping = now;
      unawaited(widget.client.typing(widget.peer, active: true)
          .catchError((Object _) {}));
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 4), () {
      _lastTyping = null;
      unawaited(widget.client.typing(widget.peer, active: false)
          .catchError((Object _) {}));
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    try {
      final all = await widget.client.history();
      final selected = all.where((message) => message.peer == widget.peer).toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(selected);
        _error = null;
      });
      for (final message in selected) {
        if (!message.incoming || !_delivered.add(message.id)) continue;
        // Server storage is not device delivery; this client fetched the CPIM.
        unawaited(widget.client.acknowledge(widget.peer, message.id)
            .catchError((Object _) { _delivered.remove(message.id); }));
      }
      // Only a foreground visible conversation counts as read. Opening the
      // inbox must never produce a displayed receipt.
      _markVisibleMessagesRead(selected);
      // The backend's /messages history is append-only, so message.state can
      // remain "queued" after the receiver reports delivered/displayed.
      // Query only the 16 newest outgoing messages concurrently.
      final outbound = selected.where((m) => !m.incoming).toList();
      final latest = outbound.length <= 16
          ? outbound
          : outbound.sublist(outbound.length - 16);
      final states = <String, String>{};
      await Future.wait(latest.map((message) async {
        try {
          states[message.id] = await widget.client.status(message.id);
        } catch (_) {
          // Keep last known acknowledgement on a transient network error.
        }
      }));
      if (!mounted) return;
      setState(() => _outgoingStates.addAll(states));
    } on PyreRcsException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load RCS conversation.');
    } finally {
      _refreshing = false;
      if (_refreshPending && mounted) {
        _refreshPending = false;
        unawaited(_refresh());
      }
    }
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.client.send(widget.peer, content);
      if (!mounted) return;
      // A network send can take seconds. Text composed during that wait is
      // the next draft and must not be discarded when this send completes.
      if (_composer.text.trim() == content) {
        _composer.clear();
      }
      await _refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.minScrollExtent,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut);
        }
      });
    } on PyreRcsException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'RCS send failed. Retry.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _conversationVisible {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return false;
    return mounted && (ModalRoute.of(context)?.isCurrent ?? false);
  }

  void _markVisibleMessagesRead(Iterable<PyreRcsMessage> messages) {
    if (!_conversationVisible) return;
    for (final message in messages) {
      if (!message.incoming || !_read.add(message.id)) continue;
      unawaited(widget.client.acknowledge(widget.peer, message.id, read: true)
          .catchError((Object _) { _read.remove(message.id); }));
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = widget.client.handle;
    return Scaffold(
      backgroundColor: PyreColors.night,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: PyreColors.night,
        foregroundColor: PyreColors.nightText,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundColor: PyreColors.nightLine,
              child: Icon(Icons.person_outline_rounded,
                  color: PyreColors.nightMuted, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'RCS chat · Not end-to-end encrypted',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11, color: PyreColors.nightMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.orangeAccent)),
              ),
            if (widget.client.typingPeer == widget.peer)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Typing…',
                      style: TextStyle(color: PyreColors.emberGlow)),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  key: const Key('rcs_thread_messages'),
                  controller: _scroll,
                  // A reversed list is anchored at the latest message (offset 0)
                  // when the Android/web soft keyboard resizes the viewport.
                  // Browsing older messages retains its offset instead of
                  // jumping to the newest message on every keyboard change.
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final message = _messages[_messages.length - 1 - i];
                    final outgoing = message.from == self;
                    return Align(
                      alignment: outgoing
                          ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 3,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: outgoing
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                key: Key('rcs_bubble_${message.id}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: outgoing
                                      ? PyreColors.nightCardStrong
                                      : const Color(0xFF28252A),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(22),
                                    topRight: const Radius.circular(22),
                                    bottomLeft: Radius.circular(
                                      outgoing ? 22 : 7,
                                    ),
                                    bottomRight: Radius.circular(
                                      outgoing ? 7 : 22,
                                    ),
                                  ),
                                ),
                                child: SelectableText(
                                  message.body,
                                  style: const TextStyle(
                                    color: PyreColors.nightText,
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (outgoing)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 3, right: 8,
                                  ),
                                  child: Text(
                                    PyreRcsProtocol.messageStatusLabel(
                                      _outgoingStates[message.id] ?? message.state,
                                    ),
                                    style: const TextStyle(
                                      color: PyreColors.nightMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('rcs_composer'),
                      controller: _composer,
                      style: const TextStyle(
                        color: PyreColors.nightText,
                        fontSize: 16,
                      ),
                      cursorColor: PyreColors.emberGlow,
                      keyboardAppearance: Brightness.dark,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 12000,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: PyreColors.nightCardStrong,
                        hintText: 'RCS message',
                        hintStyle: const TextStyle(color: PyreColors.nightMuted),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14,
                        ),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: const BorderSide(
                            color: PyreColors.nightLine,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: const BorderSide(
                            color: PyreColors.nightLine,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: const BorderSide(
                            color: PyreColors.emberGlow, width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _composer,
                    builder: (context, draft, _) => IconButton.filled(
                      key: const Key('rcs_send'),
                      onPressed: _sending || draft.text.trim().isEmpty
                          ? null
                          : _send,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: PyreColors.emberGlow,
                        foregroundColor: PyreColors.night,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      tooltip: 'Send RCS message',
                    ),
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
