import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/capture_send_target.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/capture/capture_screen.dart';
import 'package:pyrechat_flutter/screens/chats/chats_screen.dart';
import 'package:pyrechat_flutter/screens/profile/profile_screen.dart';
import 'package:pyrechat_flutter/services/client_identity.dart';
import 'package:pyrechat_flutter/services/profile_photo_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_analytics.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_mls.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/services/pyre_notifications.dart';
import 'package:pyrechat_flutter/theme/pyre_motion.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/leave_app_dialog.dart';
import 'package:pyrechat_flutter/widgets/pyre_bottom_nav.dart';

// Bounded backoff: no busy polling, eventual recovery even after long outages.
int encryptionRegistrationBackoffSeconds(int attempt) {
  const seconds = [2, 4, 8, 15, 30, 60];
  return seconds[attempt.clamp(0, seconds.length - 1)];
}

enum _AppTab { chats, camera, profile }

class AppConnectionStatusLabel extends StatelessWidget {
  const AppConnectionStatusLabel({super.key, required this.status});

  final PyreHubStatus status;

  @override
  Widget build(BuildContext context) {
    final reconnecting = status == PyreHubStatus.reconnecting;
    return Semantics(
      liveRegion: true,
      label: reconnecting ? 'Reconnecting to PyreChat' : 'You are offline',
      child: ExcludeSemantics(
        child: Text(
          reconnecting ? 'Reconnecting…' : 'You are offline',
          style: const TextStyle(
            color: PyreColors.nightText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key, required this.user});

  final PyreUser user;

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen>
    with WidgetsBindingObserver {
  static const _tabs = _AppTab.values;
  final _captureKey = GlobalKey<CaptureScreenState>();
  final _chatsKey = GlobalKey<ChatsScreenState>();
  final _hub = PyreHub();
  final _mlsProvisioner = PyreMlsProvisioner();

  late final PageController _pages;
  late PyreUser _user;
  _AppTab _tab = _AppTab.chats;
  CaptureSendTarget? _captureTarget;
  bool _appResumed = true;
  bool _pushRegistered = false;
  bool _mlsSyncing = false;
  Timer? _mlsRetryTimer;
  int _mlsRetryAttempt = 0;
  late PyreHubStatus _hubStatus;
  Timer? _typingNoticeExpiry;
  String? _typingNotice;
  String? _typingNoticeChatId;

  void _onHubEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == 'pong') return;

    if (type == 'e2ee_device_needed' || type == 'e2ee_key_package_needed') {
      unawaited(_syncEncryptionDevice());
    }

    // Suppress a system notification only when the exact conversation is
    // already visible. Being on the Chats tab/list should still notify.
    final eventChatId = (event['conversationId'] ??
            event['chatId'] ??
            event['conversation_id'])
        ?.toString();
    final activeChatId = _chatsKey.currentState?.activeChatId;
    final viewingExactThread = _appResumed &&
        _tab == _AppTab.chats &&
        eventChatId != null &&
        eventChatId.isNotEmpty &&
        eventChatId == activeChatId;

    if (type == 'typing') {
      final active = event['active'] != false;
      if (!active || viewingExactThread) {
        if (_typingNoticeChatId == eventChatId && _typingNotice != null && mounted) {
          _typingNoticeExpiry?.cancel();
          setState(() {
            _typingNotice = null;
            _typingNoticeChatId = null;
          });
        }
        return;
      }
      if (_appResumed && eventChatId != null && eventChatId.isNotEmpty) {
        final rawName = event['fromName']?.toString().trim();
        final name = rawName == null || rawName.isEmpty ? 'Someone' : rawName;
        final firstName = name.split(RegExp(r'\s+')).first;
        _typingNoticeExpiry?.cancel();
        if (mounted) {
          setState(() {
            _typingNotice = '$firstName is typing…';
            _typingNoticeChatId = eventChatId;
          });
        }
        _typingNoticeExpiry = Timer(const Duration(milliseconds: 3800), () {
          if (!mounted || _typingNoticeChatId != eventChatId) return;
          setState(() {
            _typingNotice = null;
            _typingNoticeChatId = null;
          });
        });
      }
      return;
    }

    if ((_appResumed && !viewingExactThread) ||
        (!_appResumed && !_pushRegistered)) {
      PyreNotifications.instance.handleHubEvent(event);
    }

    if (type == 'chat' ||
        type == 'snap' ||
        type == 'notification' ||
        event['kind'] == 'snap') {
      _chatsKey.currentState?.reload(silent: true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user = widget.user;
    _pages = PageController(initialPage: _tab.index);
    _hubStatus = _hub.status;
    PyreAnalytics.instance.track('app_open', surface: 'signed_in_shell');
    PyreAnalytics.instance.track('session_start', surface: 'signed_in_shell');
    PyreAnalytics.instance.track('view_inbox', surface: 'chats');
    _hub.addListener(_onHubEvent);
    _hub.addStatusListener(_onHubStatus);
    _hub.connect();
    unawaited(
      PyreNotifications.instance.setContext(
        foreground: true,
        activeConversationId: null,
      ),
    );
    unawaited(_syncPushRegistration());
    unawaited(_syncEncryptionDevice());
    unawaited(ProfilePhotoPrefs.instance.loadFor(_user.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_consumeNotificationLaunch());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      PyreNotifications.instance.setContext(
        foreground: false,
        activeConversationId: null,
      ),
    );
    _typingNoticeExpiry?.cancel();
    _mlsRetryTimer?.cancel();
    _hub.removeListener(_onHubEvent);
    _hub.removeStatusListener(_onHubStatus);
    _hub.disconnect();
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    unawaited(
      PyreNotifications.instance.setContext(
        foreground: _appResumed,
        activeConversationId: _chatsKey.currentState?.activeChatId,
      ),
    );
    if (!_appResumed) return;

    _hub.reconnect();
    unawaited(_syncPushRegistration());
    unawaited(_syncEncryptionDevice());
    unawaited(_consumeNotificationLaunch());
    _chatsKey.currentState?.reload(silent: true);
  }

  void _onHubStatus(PyreHubStatus status) {
    if (!mounted || status == _hubStatus) return;
    setState(() => _hubStatus = status);
  }

  Future<void> _syncPushRegistration() async {
    final registered =
        await PyreNotifications.instance.syncPushRegistration();
    if (!mounted || registered == _pushRegistered) return;
    setState(() => _pushRegistered = registered);
  }

  Future<void> _consumeNotificationLaunch() async {
    final chatId =
        await PyreNotifications.instance.takeLaunchConversationId();
    if (!mounted || chatId == null || chatId.isEmpty) return;

    _goToTab(_AppTab.chats);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chats = _chatsKey.currentState;
      if (chats != null) {
        unawaited(chats.openConversation(chatId, fromNotification: true));
      }
    });
  }

  // Retry browser key provisioning independently of realtime socket status.
  // Failed startup/key-registration must not stay broken until the next login.
  void _scheduleEncryptionRetry() {
    if (!mounted || (_mlsRetryTimer?.isActive ?? false)) return;
    _mlsRetryTimer = Timer(
      Duration(seconds: encryptionRegistrationBackoffSeconds(_mlsRetryAttempt++)),
      () {
        _mlsRetryTimer = null;
        if (mounted) unawaited(_syncEncryptionDevice());
      },
    );
  }

  Future<void> _syncEncryptionDevice() async {
    if (_mlsSyncing) return;
    _mlsSyncing = true;
    try {
      final client = PyreClient();
      final sync = await _mlsProvisioner.syncRegistration(
        client: client,
        userId: _user.id,
      );
      final deviceId = sync.deviceId;
      if (!sync.registered || deviceId == null || deviceId.isEmpty) {
        _scheduleEncryptionRetry();
        return;
      }
      await client.bindCurrentSessionDevice(
        deviceId: deviceId,
        label: pyreClientLabel(),
      );
      _mlsRetryTimer?.cancel();
      _mlsRetryTimer = null;
      _mlsRetryAttempt = 0;
    } catch (_) {
      // WebCrypto, network and server outages must not silently strand users.
      _scheduleEncryptionRetry();
    } finally {
      _mlsSyncing = false;
    }
  }

  void _openCamera(CaptureSendTarget? target) {
    if (mounted) setState(() => _captureTarget = target);
    _goToTab(_AppTab.camera);
  }

  void _clearCaptureTarget() {
    if (_captureTarget == null || !mounted) return;
    setState(() => _captureTarget = null);
  }

  void _onUserChanged(PyreUser user) {
    if (!mounted) return;
    setState(() => _user = user);
  }

  void _trackTab(_AppTab tab) {
    switch (tab) {
      case _AppTab.chats:
        PyreAnalytics.instance.track('view_inbox', surface: 'chats');
        break;
      case _AppTab.camera:
        PyreAnalytics.instance.track('view_capture', surface: 'camera');
        PyreAnalytics.instance.track('camera_open', surface: 'camera');
        break;
      case _AppTab.profile:
        PyreAnalytics.instance.track('view_you', surface: 'profile');
        break;
    }
  }

  void _goToTab(_AppTab tab) {
    if (tab != _AppTab.camera && _captureTarget != null) {
      _clearCaptureTarget();
    }
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _trackTab(tab);
    _pages.animateToPage(
      tab.index,
      duration: PyreMotion.standard,
      curve: PyreMotion.enter,
    );
  }

  void _onPageChanged(int index) {
    final next = _tabs[index];
    if (next != _AppTab.camera && _captureTarget != null) {
      _clearCaptureTarget();
    }
    if (_tab == next) return;
    setState(() => _tab = next);
    _trackTab(next);

    if (next == _AppTab.camera) {
      _captureKey.currentState?.reloadCustomLenses();
    }
    if (next == _AppTab.chats) {
      _chatsKey.currentState?.reload(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        maybeLeaveApp(context);
      },
      child: Scaffold(
        backgroundColor: PyreColors.night,
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: PageView(
                controller: _pages,
                onPageChanged: _onPageChanged,
                physics: const PageScrollPhysics(),
                children: [
                  ChatsScreen(
                    key: _chatsKey,
                    hub: _hub,
                    user: _user,
                    onGoCamera: _openCamera,
                  ),
                  CaptureScreen(
                    key: _captureKey,
                    active: _tab == _AppTab.camera,
                    sendTarget: _captureTarget,
                    onSendTargetConsumed: _clearCaptureTarget,
                    onGoChats: () => _goToTab(_AppTab.chats),
                    onGoProfile: () => _goToTab(_AppTab.profile),
                  ),
                  ProfileScreen(
                    user: _user,
                    onUserChanged: _onUserChanged,
                  ),
                ],
              ),
            ),
            if (_typingNotice != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(48, 12, 48, 0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: PyreColors.nightCardStrong
                                .withValues(alpha: 0.97),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: PyreColors.emberGlow
                                  .withValues(alpha: 0.28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.more_horiz_rounded,
                                color: PyreColors.emberGlow,
                                size: 19,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  _typingNotice!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PyreColors.nightText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_hubStatus == PyreHubStatus.disconnected ||
                _hubStatus == PyreHubStatus.reconnecting)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: PyreColors.nightCardStrong
                                .withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: AppConnectionStatusLabel(
                            status: _hubStatus,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _tab == _AppTab.camera
            ? null
            : PyreBottomNav(
                selectedIndex: _tab.index,
                onSelected: (i) => _goToTab(_tabs[i]),
              ),
      ),
    );
  }
}
